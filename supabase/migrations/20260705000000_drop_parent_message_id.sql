-- parent_message_id was reserved for follow-up analytics but is never populated.
-- Multi-turn context is injected client-side (see ConversationSession); DB query not needed.
ALTER TABLE messages DROP COLUMN IF EXISTS parent_message_id;
