-- Christian Camps, Bible Institutes, and Training Centers
-- Sample SQL INSERT statements for organizations and staff

-- Organizations Table
INSERT INTO organizations (id, name, type, description, email, phone, website, city, state, country) VALUES
(1, 'Grace Mountain Christian Camp', 'camp', 'Summer camp for youth ages 8-18', 'info@gracemountaincamp.org', '(719) 555-0101', 'www.gracemountaincamp.org', 'Colorado Springs', 'CO', 'USA'),
(2, 'Living Word Bible Institute', 'institute', 'Two-year Bible training program for emerging leaders', 'admissions@livingwordbi.edu', '(615) 555-0102', 'www.livingwordbi.edu', 'Nashville', 'TN', 'USA'),
(3, 'Cornerstone Leadership Training Center', 'training', 'Discipleship and leadership development programs', 'contact@cornerstoneltc.org', '(404) 555-0103', 'www.cornerstoneltc.org', 'Atlanta', 'GA', 'USA'),
(4, 'Harvest Valley Christian Camp', 'camp', 'Multi-week family and youth camps in scenic valley setting', 'admin@harvestvalleycamp.org', '(503) 555-0104', 'www.harvestvalleycamp.org', 'Salem', 'OR', 'USA'),
(5, 'Kingdom Bible College', 'institute', 'Accredited Bible college offering associate and bachelor degrees', 'registrar@kingdombible.edu', '(816) 555-0105', 'www.kingdombible.edu', 'Kansas City', 'MO', 'USA'),
(6, 'New Hope Mission Training Academy', 'training', 'Missionary training and cross-cultural ministry preparation', 'info@newhopeacademy.org', '(206) 555-0106', 'www.newhopeacademy.org', 'Seattle', 'WA', 'USA'),
(7, 'Summit Ridge Christian Camp', 'camp', 'Overnight and day camps with specialized programs', 'director@summitridgecamp.org', '(970) 555-0107', 'www.summitridgecamp.org', 'Denver', 'CO', 'USA'),
(8, 'Reformation Institute for Biblical Studies', 'institute', 'Seminary-level theological training', 'admissions@reformation.edu', '(412) 555-0108', 'www.reformation.edu', 'Pittsburgh', 'PA', 'USA');

-- Staff Table
INSERT INTO staff (id, org_id, first_name, last_name, position, email, phone, role_type, support_raising_url, personal_website, bio) VALUES
(1, 1, 'David', 'Henderson', 'Camp Director', 'david.henderson@gracemountaincamp.org', '(719) 555-0201', 'director', 'www.supportdavid.org', 'www.davidhenderson.net', 'Director for 15 years with passion for youth transformation'),
(2, 1, 'Jennifer', 'Martinez', 'Program Coordinator', 'j.martinez@gracemountaincamp.org', '(719) 555-0202', 'staff', 'www.jenniferserves.org', NULL, 'Oversees worship and discipleship programs'),
(3, 2, 'Robert', 'Chen', 'Principal', 'r.chen@livingwordbi.edu', '(615) 555-0203', 'director', 'www.supportrobert.org', 'www.robertchen.com', 'Leading biblical education and ministry formation'),
(4, 2, 'Sarah', 'Williams', 'Outreach Coordinator', 's.williams@livingwordbi.edu', '(615) 555-0204', 'staff', 'www.sarahwilliams.org', 'www.sarahministry.blog', 'Recruiting and mentoring next generation leaders'),
(5, 3, 'Michael', 'Johnson', 'Executive Director', 'm.johnson@cornerstoneltc.org', '(404) 555-0205', 'director', 'www.michaeljohnson.org', 'www.mjohnson-ministry.com', 'Vision casting and strategic development'),
(6, 3, 'Amanda', 'Rodriguez', 'Training Director', 'a.rodriguez@cornerstoneltc.org', '(404) 555-0206', 'staff', 'www.amandaministry.org', NULL, 'Curriculum development and instructor oversight'),
(7, 4, 'James', 'Thompson', 'Camp Director', 'james@harvestvalleycamp.org', '(503) 555-0207', 'director', 'www.jthompson-support.com', 'www.jamesministry.org', 'Building multigenerational ministry impact'),
(8, 5, 'Patricia', 'Anderson', 'Dean of Students', 'p.anderson@kingdombible.edu', '(816) 555-0208', 'director', 'www.patriciasupport.org', 'www.patriciaministry.net', 'Student development and pastoral care'),
(9, 6, 'Christopher', 'Lee', 'Training Director', 'c.lee@newhopeacademy.org', '(206) 555-0209', 'staff', 'www.christopherlee-missions.org', 'www.christopherlee.blog', 'Equipping missionaries for global work'),
(10, 7, 'Elizabeth', 'White', 'Director of Programs', 'elizabeth@summitridgecamp.org', '(970) 555-0210', 'director', 'www.elizabethwhite.org', 'www.elizabeth-ministry.com', 'Innovative programming for spiritual growth');
