-- Add ip_address column to users table
ALTER TABLE public.users 
ADD COLUMN ip_address VARCHAR(45) DEFAULT NULL;

-- Add index for faster IP address lookups
CREATE INDEX idx_users_ip_address ON public.users(ip_address);

-- Add comment to document the column
COMMENT ON COLUMN public.users.ip_address IS 'Current IP address of the user device, updated on each login';
