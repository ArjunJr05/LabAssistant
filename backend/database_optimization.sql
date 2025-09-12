-- Database Optimization Script for Lab Assistant
-- This script creates indexes to improve query performance and reduce latency

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_is_online ON users (is_online);
CREATE INDEX IF NOT EXISTS idx_users_enroll_number ON users (enroll_number);
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
CREATE INDEX IF NOT EXISTS idx_users_last_active ON users (last_active);
CREATE INDEX IF NOT EXISTS idx_users_role_online ON users (role, is_online);

-- Subjects table indexes
CREATE INDEX IF NOT EXISTS idx_subjects_name ON subjects (name);
CREATE INDEX IF NOT EXISTS idx_subjects_created_at ON subjects (created_at);

-- Exercises table indexes
CREATE INDEX IF NOT EXISTS idx_exercises_subject_id ON exercises (subject_id);
CREATE INDEX IF NOT EXISTS idx_exercises_created_at ON exercises (created_at);
CREATE INDEX IF NOT EXISTS idx_exercises_title ON exercises (title);
CREATE INDEX IF NOT EXISTS idx_exercises_subject_created ON exercises (subject_id, created_at);

-- Submissions table indexes
CREATE INDEX IF NOT EXISTS idx_submissions_user_id ON submissions (user_id);
CREATE INDEX IF NOT EXISTS idx_submissions_exercise_id ON submissions (exercise_id);
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_at ON submissions (submitted_at);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON submissions (status);
CREATE INDEX IF NOT EXISTS idx_submissions_user_exercise ON submissions (user_id, exercise_id);
CREATE INDEX IF NOT EXISTS idx_submissions_recent ON submissions (submitted_at DESC);

-- Student activities indexes (already exists but ensuring completeness)
CREATE INDEX IF NOT EXISTS idx_student_activities_user_id ON student_activities (user_id);
CREATE INDEX IF NOT EXISTS idx_student_activities_exercise_id ON student_activities (exercise_id);
CREATE INDEX IF NOT EXISTS idx_student_activities_created_at ON student_activities (created_at);
CREATE INDEX IF NOT EXISTS idx_student_activities_activity_type ON student_activities (activity_type);
CREATE INDEX IF NOT EXISTS idx_student_activities_status ON student_activities (status);
CREATE INDEX IF NOT EXISTS idx_student_activities_user_recent ON student_activities (user_id, created_at DESC);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_users_online_students ON users (role, is_online) WHERE role = 'student';
CREATE INDEX IF NOT EXISTS idx_submissions_recent_with_user ON submissions (submitted_at DESC, user_id, exercise_id);
CREATE INDEX IF NOT EXISTS idx_exercises_with_subject ON exercises (subject_id, title, created_at);

-- Add database statistics update for better query planning
ANALYZE users;
ANALYZE subjects;
ANALYZE exercises;
ANALYZE submissions;
ANALYZE student_activities;

-- Comments for documentation
COMMENT ON INDEX idx_users_role_online IS 'Optimizes queries filtering by role and online status';
COMMENT ON INDEX idx_submissions_recent IS 'Optimizes recent submissions queries with DESC order';
COMMENT ON INDEX idx_users_online_students IS 'Partial index for online student queries';
