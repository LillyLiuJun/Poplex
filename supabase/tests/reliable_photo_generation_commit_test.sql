begin;

select plan(9);

-- This helper proves an invalid core-material payload cannot leave the message pair behind.
create function pg_temp.invalid_material_rolls_back()
returns boolean
language plpgsql
as $$
declare
  v_user_id constant uuid := '11111111-1111-1111-1111-111111111111';
  v_request_id constant uuid := '22222222-2222-2222-2222-222222222222';
begin
  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  begin
    perform public.commit_generated_content(
      v_request_id,
      jsonb_build_object(
        'input_type', 'image',
        'user_content', '[photo] rollback',
        'source', 'onboarding'
      ),
      jsonb_build_object(
        'card_type', 's4',
        'card_content', jsonb_build_object('title', 'Rollback card')
      ),
      jsonb_build_object(
        'material_type', 'not-a-material-type',
        'raw_content', jsonb_build_object('user_original', '[photo] rollback'),
        'source', 'onboarding'
      )
    );
    return false;
  exception when check_violation then
    return (
      select count(*) = 0
      from public.messages
      where user_id = v_user_id
        and request_id = v_request_id
    ) and (
      select count(*) = 0
      from public.materials
      where user_id = v_user_id
        and request_id = v_request_id
    );
  end;
end;
$$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$
    select public.commit_generated_content(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      '{}'::jsonb,
      '{}'::jsonb,
      null
    )
  $$,
  '42501',
  null,
  'unauthenticated callers are rejected with insufficient privilege'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);

select is(
  (
    public.commit_generated_content(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      jsonb_build_object(
        'input_type', 'image',
        'user_content', '[photo] first user',
        'source', 'onboarding'
      ),
      jsonb_build_object(
        'card_type', 's4',
        'card_content', jsonb_build_object('title', 'First user card'),
        'extracted_concept', 'describe a photo'
      ),
      jsonb_build_object(
        'material_type', 'scene',
        'status', 'categorized',
        'raw_content', jsonb_build_object('user_original', '[photo] first user'),
        'source', 'onboarding'
      )
    )->>'already_committed'
  ),
  'false',
  'the first authenticated request is newly committed'
);

select is(
  (
    select count(*)::integer
    from public.messages
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid
      and request_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  2,
  'the committed request has exactly two messages owned by the caller'
);

select is(
  (
    select count(*)::integer
    from public.materials
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid
      and request_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  1,
  'the committed request has exactly one material owned by the caller'
);

select is(
  (
    public.commit_generated_content(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      jsonb_build_object('user_content', 'ignored retry payload'),
      jsonb_build_object('card_type', 's1', 'card_content', jsonb_build_object('title', 'Ignored retry card')),
      jsonb_build_object('material_type', 'vocabulary')
    )->>'already_committed'
  ),
  'true',
  'a same-user retry reports an existing committed operation'
);

select is(
  (
    public.commit_generated_content(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      jsonb_build_object('user_content', 'ignored retry payload'),
      jsonb_build_object(
        'card_type', 's1',
        'card_content', jsonb_build_object('title', 'Ignored retry card'),
        'extracted_concept', 'racing concept'
      ),
      jsonb_build_object('material_type', 'vocabulary')
    )->>'extracted_concept'
  ),
  'describe a photo',
  'a same-user retry returns the stored extracted concept'
);

select is(
  (
    select count(*)::text || ':' || (
      select count(*)::text
      from public.materials
      where user_id = '11111111-1111-1111-1111-111111111111'::uuid
        and request_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
    )
    from public.messages
    where user_id = '11111111-1111-1111-1111-111111111111'::uuid
      and request_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
  ),
  '2:1',
  'a same-user retry does not add messages or materials'
);

select ok(
  pg_temp.invalid_material_rolls_back(),
  'an invalid material rolls its user and assistant message inserts back'
);

select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
select is(
  (
    public.commit_generated_content(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      jsonb_build_object(
        'input_type', 'image',
        'user_content', '[photo] second user',
        'source', 'onboarding'
      ),
      jsonb_build_object(
        'card_type', 's3',
        'card_content', jsonb_build_object('title', 'Second user card')
      ),
      jsonb_build_object(
        'material_type', 'scene',
        'raw_content', jsonb_build_object('user_original', '[photo] second user'),
        'source', 'onboarding'
      )
    )->'card_content'->>'title'
  ),
  'Second user card',
  'another user can commit the same request UUID without seeing the first result'
);

select * from finish();

rollback;
