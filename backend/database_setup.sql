-- Create student_activities table for tracking all student interactions
CREATE TABLE IF NOT EXISTS student_activities (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL CHECK (activity_type IN ('test_run', 'submission')),
    code TEXT NOT NULL,
    status VARCHAR(50) NOT NULL CHECK (status IN ('completed', 'compilation_error', 'passed', 'failed')),
    score INTEGER DEFAULT 0,
    tests_passed INTEGER DEFAULT 0,
    total_tests INTEGER DEFAULT 0,
    test_results JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_student_activities_user_id ON student_activities (user_id);
CREATE INDEX IF NOT EXISTS idx_student_activities_exercise_id ON student_activities (exercise_id);
CREATE INDEX IF NOT EXISTS idx_student_activities_created_at ON student_activities (created_at);
CREATE INDEX IF NOT EXISTS idx_student_activities_activity_type ON student_activities (activity_type);

-- Add comments for documentation
COMMENT ON TABLE student_activities IS 'Tracks all student interactions with exercises including test runs and submissions';
COMMENT ON COLUMN student_activities.activity_type IS 'Type of activity: test_run or submission';
COMMENT ON COLUMN student_activities.status IS 'Status of the activity: completed, compilation_error, passed, failed';
COMMENT ON COLUMN student_activities.test_results IS 'JSON containing detailed test results and execution data';
