# profiles 表设计方案 v1（供审阅，未实施）

> 起草日期：2026-07-07 | 对应 Tab0 PRD v2.1 第十一节 P0 项（Slice 6 前置）
> 目标读者：项目负责人（零编码背景），每个决定都附"为什么"。

---

## 一、要解决的问题

引导完成状态目前只存在手机本地（UserDefaults）。卸载重装或换设备后丢失，用户会被迫重走引导。同时，`session_count`（Tab1 变体判断需要）和 `english_level`（生成难度调节需要）在后端完全没有落脚点——因为数据库里**不存在任何用户业务表**。

`auth.users` 是 Supabase 托管的"门禁花名册"，只管登录凭证，不该塞业务字段。行业标准做法是建一张 1:1 挂钩的 `profiles` 表。

## 二、表结构

| 字段 | 类型 | 默认值 | 为什么 |
|------|------|--------|--------|
| `id` | uuid，主键 | 无（= `auth.users.id`） | 和门禁系统一对一挂钩：换设备后凭同一账号 id 找回全部状态。外键引用 `auth.users(id)`，用户注销时级联删除，不留孤儿数据 |
| `onboarding_completed_at` | timestamptz，可空 | NULL | **本表存在的首要理由**。NULL = 未完成引导；有值 = 完成时刻。它同时是 Tab1 变体 A "24 小时窗口"的计时起点（用完成时间而非注册时间，语义才对） |
| `session_count` | int，非空 | 0 | Tab1 变体判断和成长指标需要。本方案只建列、不实现计数逻辑——"什么算一次会话"的口径（冷启动？回前台超过 N 分钟？）需要先单独定义，避免埋下口径不清的数据 |
| `english_level` | text，非空 | 'B1' | Screen 3 自评推迟，PRD 决定用默认 B1。加 CHECK 约束限定 ('A1','A2','B1','B2','C1','C2')，防脏数据。列默认值让"默认 B1"由数据库保证，客户端零逻辑——这正是 PRD 第三节想要的效果 |
| `created_at` | timestamptz | now() | 常规审计字段 |
| `updated_at` | timestamptz | now() | 排查"状态什么时候变的"时需要 |

**刻意不放进来的字段**：昵称/头像（产品还没有社交面）、preset_card 相关（属 messages 表）、绑定 Apple 账号状态（`auth.users` 自己管）。原则：每个字段都要有一个已确认的消费方，不为"以后可能用"预置。

## 三、行的创建时机：数据库触发器（推荐）

两个选项：

- **选项 1 · 数据库触发器（推荐）**：`auth.users` 每新增一个用户（含匿名用户），数据库自动插入一行 profiles。
  为什么推荐：服务端自动完成，客户端零代码、零遗漏可能；这是 Supabase 官方文档推荐的标准模式；匿名登录发生在 App 启动瞬间，触发器保证 profiles 行"出生即存在"，后续所有读写不用处理"行不存在"的边界情况。
- **选项 2 · 客户端首次写入时补建（upsert）**：省一个触发器，但每处写入代码都要处理"行可能不存在"，边界情况变多，违背"引导页依赖的状态是核心不是边角"的项目原则。

## 四、RLS（行级安全）

| 操作 | 策略 | 为什么 |
|------|------|--------|
| SELECT | 只能读自己的行（`id = auth.uid()`） | 用户档案是隐私数据 |
| UPDATE | 只能改自己的行 | 客户端要写 `onboarding_completed_at`，必须放开 UPDATE，但限定本人 |
| INSERT | 不给客户端权限 | 行由触发器（服务端身份）创建，客户端永远不需要 INSERT——攻击面更小 |
| DELETE | 不给客户端权限 | 删除跟随 `auth.users` 级联，客户端无删除场景 |

## 五、客户端读写逻辑（方向，非代码）

**写**：引导完成时（现在写 UserDefaults 的同一处），同时向 profiles 表 UPDATE `onboarding_completed_at`。本地写照旧保留。

**读**：RootView 判断"进引导还是进 Tab1"时，采用**先本地、后远端**策略——
1. 本地 UserDefaults 有值 → 直接进 Tab1（快，不等网络）；
2. 本地无值 → 查询 profiles 表：远端有值说明是老用户换机/重装，补写本地后直接进 Tab1；远端也无值才进引导。

**冲突规则**：远端为权威来源，本地只是加速缓存。两边不一致时以远端为准、反向修复本地。
为什么：本地会因卸载而丢，远端不会；权威只能有一个，否则每次不一致都要人肉裁决。

**失败兜底**：远端查询失败（断网等）时按"本地无值"处理进引导——代价是极端情况下老用户重走一遍引导，比新用户被错误跳过引导（第一印象全无）伤害小。

## 六、迁移 SQL 草案（供开发时直接使用）

```sql
-- 新建 profiles 表：用户业务档案，与 auth.users 一对一。
CREATE TABLE IF NOT EXISTS profiles (
  id                       uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  onboarding_completed_at  timestamptz,          -- NULL = 未完成引导
  session_count            int  NOT NULL DEFAULT 0,
  english_level            text NOT NULL DEFAULT 'B1'
                             CHECK (english_level IN ('A1','A2','B1','B2','C1','C2')),
  created_at               timestamptz DEFAULT now(),
  updated_at               timestamptz DEFAULT now()
);

-- auth.users 新增用户（含匿名）时自动建档
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 存量用户补建档案行（上线时已有的匿名用户）
INSERT INTO public.profiles (id)
SELECT id FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_profile"
  ON profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users_update_own_profile"
  ON profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
```

## 七、开发切片建议（对应 Slice 6 拆两步）

| 步骤 | 内容 | 验收标准 |
|------|------|----------|
| 6a | 迁移上线（表 + 触发器 + 存量回填 + RLS） | 新装 App 匿名登录后 profiles 自动出现一行；存量用户都有行；用 A 用户的 token 读不到 B 用户的行 |
| 6b | 客户端接入（完成引导双写 + RootView 先本地后远端判断） | 完成引导后远端字段有值；删 App 重装（Keychain 保留会话时）不再重走引导 |

每步完成后按项目工作方法写单元测试并书面汇报结果，确认后再进下一步。

## 八、本方案不包含（明确排除）

- `session_count` 的计数逻辑（先定"会话"口径）
- Sign in with Apple 绑定（触发时机是另一个产品决策）
- Tab1 变体 A 的 24h 窗口实现（依赖本表，但属 Tab1 范围）
