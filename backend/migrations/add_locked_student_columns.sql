-- Add columns for locked student functionality
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS tab_switch_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP NULL;

-- Create index for better performance when querying locked students
CREATE INDEX IF NOT EXISTS idx_users_is_locked ON users (is_locked);
CREATE INDEX IF NOT EXISTS idx_users_locked_at ON users (locked_at);

-- Add comments for documentation
COMMENT ON COLUMN users.is_locked IS 'Whether the student account is locked due to malpractice';
COMMENT ON COLUMN users.tab_switch_count IS 'Number of tab switches detected for malpractice tracking';
COMMENT ON COLUMN users.locked_at IS 'Timestamp when the student account was locked';
