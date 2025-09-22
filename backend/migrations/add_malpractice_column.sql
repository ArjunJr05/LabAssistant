-- Add malpractice column to submissions table
ALTER TABLE submissions ADD COLUMN malpractice BOOLEAN DEFAULT FALSE;

-- Add index for faster queries on malpractice status
CREATE INDEX idx_submissions_malpractice ON submissions(student_id, exercise_id, malpractice);

-- Add column to track tab switch count for current session
ALTER TABLE submissions ADD COLUMN tab_switches INTEGER DEFAULT 0;
