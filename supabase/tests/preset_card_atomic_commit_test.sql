begin;

select plan(6);

-- Preset cards call commit_generated_content() with p_material = NULL (no scene
-- card material row, only the two messages) and expect preset_card_id to be
-- persisted on the user message — this closes the gap left by the earlier
-- reliable-photo-generation-commit migration, which never wrote that column.

set local role authenticated;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);

select is(
  (
    public.commit_generated_content(
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
      jsonb_build_object(
        'input_type', 'preset_card',
        'user_content', 'Describe this image',
        'preset_card_id', 'sample-card-1',
        'source', 'onboarding',
        'image_url', 'asset:sample1'
      ),
      jsonb_build_object(
        'card_type', 'card',
        'card_content', jsonb_build_object(
          'granularity', 'sentence',
          'direction', 'express',
          'target_expression', 'A cup of coffee sits on the table.',
          'native_meaning', '桌上放着一杯咖啡。'
        )
      ),
      null
    )->>'already_committed'
  ),
  'false',
  'a fresh preset-card commit with no material is newly committed'
);

select is(
  (
    select count(*)::integer
    from public.messages
    where user_id = '44444444-4444-4444-4444-444444444444'::uuid
      and request_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
  ),
  2,
  'the preset-card commit writes exactly the two messages, no material'
);

select is(
  (
    select preset_card_id
    from public.messages
    where user_id = '44444444-4444-4444-4444-444444444444'::uuid
      and request_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
      and role = 'user'
  ),
  'sample-card-1',
  'preset_card_id is persisted on the user message'
);

select is(
  (
    public.commit_generated_content(
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
      jsonb_build_object('user_content', 'ignored retry payload', 'preset_card_id', 'ignored-on-retry'),
      jsonb_build_object('card_type', 'card', 'card_content', jsonb_build_object('title', 'ignored')),
      null
    )->>'already_committed'
  ),
  'true',
  'a same-request_id retry reports an existing committed operation, no double-save'
);

select is(
  (
    select material_id::text
    from (
      select public.commit_generated_content(
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
        jsonb_build_object('user_content', 'ignored retry payload'),
        jsonb_build_object('card_type', 'card', 'card_content', jsonb_build_object('title', 'ignored')),
        null
      ) as result
    ) t, jsonb_to_record(t.result) as r(material_id uuid)
  ),
  null,
  'a preset-card commit never fabricates a material_id'
);

-- A different attempt (new request_id) for the same user re-picking the same
-- preset card is a legitimate independent record, not a duplicate to reject.
select is(
  (
    public.commit_generated_content(
      'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid,
      jsonb_build_object(
        'input_type', 'preset_card',
        'user_content', 'Describe this image',
        'preset_card_id', 'sample-card-1',
        'source', 'onboarding'
      ),
      jsonb_build_object(
        'card_type', 'card',
        'card_content', jsonb_build_object('target_expression', 'A second, independent attempt.')
      ),
      null
    )->>'already_committed'
  ),
  'false',
  'a different request_id for the same preset card is its own independent record'
);

select * from finish();

rollback;
