-- Create malpractice_logs table for tracking student malpractice incidents
CREATE TABLE IF NOT EXISTS malpractice_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- e.g., 'tab_switching', 'copy_paste', 'unauthorized_access'
    description TEXT NOT NULL,
    violation_count INTEGER NOT NULL DEFAULT 1,
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_malpractice_logs_user_id ON malpractice_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_malpractice_logs_exercise_id ON malpractice_logs(exercise_id);
CREATE INDEX IF NOT EXISTS idx_malpractice_logs_user_exercise ON malpractice_logs(user_id, exercise_id);
CREATE INDEX IF NOT EXISTS idx_malpractice_logs_is_blocked ON malpractice_logs(is_blocked);
CREATE INDEX IF NOT EXISTS idx_malpractice_logs_created_at ON malpractice_logs(created_at);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_malpractice_logs_updated_at 
    BEFORE UPDATE ON malpractice_logs 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
