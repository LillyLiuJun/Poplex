# Debug Probes（DEBUG-only 常备验收探针）

> 从 `CLAUDE.md` 迁出（2026-10-18 精简），内容原样保留。`MineView.swift` / `Tab2HomeViewModel.swift` / `ToastRegressionTests.swift` 的注释仍写作 CLAUDE.md「Debug Probes」，该节现在只剩一个指向本文的入口。


真机曾现「toast 弹出后常驻不消失」（2026-09-15，结论：rebase 前构建的旧包，
当前代码无法复现；探针保留，再现时立即抓日志）。三条 toast（comingSoon /
vm.toastMessage / milestone）共用 AppToast 的自动消失链路，MineView 内置
常备探针验证该链路，全部包在 `#if DEBUG`，不进 Release。

| 环境变量 | 触发 |
|---|---|
| `TOAST_PROBE=1` | 进入 Tab2 后 2s 自动写 comingSoonToast（"Speaking mode will be available soon."） |
| `TOAST_PROBE_BLOCKED=1` | Tab2 load 成功后自动写 vm.toastMessage（"You're offline. Check your connection."） |
| `TAB2_MILESTONE_DEMO=1` | Tab2 刷新时写入里程碑演示数据；切走再切回 Tab2 触发 milestoneToast |

验收标准（三者共用）：日志前缀 `[toast-probe]`，验证的是 **toast 写入 →
自动清空的全链路时序**——每条写入必须后跟一条 nil（3s / 2.2s 附近），
只有写入没有 nil = 自动消失链路坏。注意：设备 console 是管道、stdout
全缓冲，`print()` 不可见，探针必须走 NSLog（os_log 通道）。
