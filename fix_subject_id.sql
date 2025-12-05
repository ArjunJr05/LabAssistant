-- Fix: Update all exercises to use the correct subject_id
-- The subject "c" has id = 11, but exercises were inserted with subject_id = 1

UPDATE public.exercises 
SET subject_id = 11 
WHERE subject_id = 1;

-- Verify the update
SELECT 
  s.id as subject_id, 
  s.name as subject_name, 
  COUNT(e.id) as exercise_count
FROM subjects s
LEFT JOIN exercises e ON s.id = e.subject_id
GROUP BY s.id, s.name
ORDER BY s.id;
