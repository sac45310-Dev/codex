-- Chi Alpha Campus Ministry Support Platform - Sample Data

-- Insert staff and planters (7 records)
INSERT INTO staff (id, name, email, role, campus, status, created_at) VALUES
  ('staff-001', 'Sarah Johnson', 'sarah.johnson@chialpha.org', 'campus-planter', 'UC Berkeley', 'active', NOW()),
  ('staff-002', 'Marcus Chen', 'marcus.chen@chialpha.org', 'campus-director', 'Stanford University', 'active', NOW()),
  ('staff-003', 'Jessica Rodriguez', 'jessica.rodriguez@chialpha.org', 'campus-planter', 'UCLA', 'active', NOW()),
  ('staff-004', 'David Kim', 'david.kim@chialpha.org', 'regional-director', 'Northern California', 'active', NOW()),
  ('staff-005', 'Emily Martinez', 'emily.martinez@chialpha.org', 'campus-planter', 'UC Davis', 'active', NOW()),
  ('staff-006', 'James Thompson', 'james.thompson@chialpha.org', 'campus-planter', 'San Jose State', 'active', NOW()),
  ('staff-007', 'Rachel Lee', 'rachel.lee@chialpha.org', 'campus-director', 'UC Irvine', 'active', NOW());

-- Insert giving pages (7 records)
INSERT INTO giving_pages (id, staff_id, slug, title, description, goal_amount, current_amount, status, created_at) VALUES
  ('giving-001', 'staff-001', 'sarah-berkeley-ministry', 'Berkeley Campus Ministry Support', 'Help support Chi Alpha''s ministry at UC Berkeley reaching students with the Gospel', 15000.00, 8500.00, 'active', NOW()),
  ('giving-002', 'staff-002', 'marcus-stanford-ministry', 'Stanford University Chi Alpha', 'Supporting evangelism and discipleship at Stanford University', 20000.00, 12750.00, 'active', NOW()),
  ('giving-003', 'staff-003', 'jessica-ucla-campus', 'UCLA Chi Alpha Ministry Fund', 'Reaching UCLA students with Christ-centered community and teaching', 18000.00, 9200.00, 'active', NOW()),
  ('giving-004', 'staff-004', 'david-regional-impact', 'Northern California Regional Ministry', 'Regional leadership and coordination for Chi Alpha across NorCal', 25000.00, 15000.00, 'active', NOW()),
  ('giving-005', 'staff-005', 'emily-davis-outreach', 'UC Davis Outreach & Discipleship', 'Equipping student leaders and reaching the UC Davis campus', 12000.00, 6300.00, 'active', NOW()),
  ('giving-006', 'staff-006', 'james-sjsu-multiplication', 'San Jose State Chi Alpha Growth', 'Multiplication and expansion of Gospel community at SJSU', 16000.00, 11200.00, 'active', NOW()),
  ('giving-007', 'rachel-irvine', 'rachel-uci-support', 'UC Irvine Ministry Partnership', 'Partnering with UCI students to establish Christ-centered community', 14000.00, 7850.00, 'active', NOW());

-- Insert prayer letters (8 records)
INSERT INTO prayer_letters (id, staff_id, title, content, published_at, created_at) VALUES
  ('letter-001', 'staff-001', 'November Prayer Letter - Sarah Johnson', 'Dear Partners in Ministry,

This month we''ve seen incredible growth in Bible study attendance. Please pray for wisdom as we disciple new believers in navigating their faith on campus.

In Christ,
Sarah', '2026-11-01', NOW()),
  ('letter-002', 'staff-002', 'October Update - Marcus Chen', 'Greetings from Stanford,

The Lord has opened doors to reach graduate students through small group studies. Pray for boldness as we tackle tough questions about faith and academics.

Blessings,
Marcus', '2026-10-15', NOW()),
  ('letter-003', 'staff-003', 'December Prayer Request - Jessica', 'Dear Friends,

As finals approach, we''re intensifying our outreach to stressed and searching students. Pray for fruit and for our team''s endurance through the busy season.

In His service,
Jessica', '2026-12-01', NOW()),
  ('letter-004', 'staff-004', 'Fall Leadership Training - David', 'Regional Prayer Update,

We just completed regional leader training with 25 student leaders. Pray for their spiritual growth and the multiplication of their impact on their campuses.

Gratefully,
David', '2026-11-15', NOW()),
  ('letter-005', 'staff-005', 'New Semester Beginnings - Emily', 'Dear Prayer Warriors,

Fall semester brought 40 new students to our initial outreach events. Pray that seeds planted will take root and produce spiritual fruit.

Praying with you,
Emily', '2026-09-20', NOW()),
  ('letter-006', 'staff-006', 'Discipleship Focus - James', 'Friends & Prayer Partners,

We''re launching a new discipleship track focused on spiritual disciplines. Pray for faithfulness as we help students grow in Christ-likeness.

Your brother in Christ,
James', '2026-11-01', NOW()),
  ('letter-007', 'staff-007', 'Winter Break Vision - Rachel', 'Beloved Partners,

Many of our students will be home for winter break. Pray they''ll be bold witnesses to their families and home churches.

Standing with you in prayer,
Rachel', '2026-12-10', NOW()),
  ('letter-008', 'staff-001', 'December Follow-Up - Sarah', 'Prayer Partners,

Thank you for praying for our year-end outreach events. We saw 15 new attendees give their lives to Christ. Praise God!

Faithfully,
Sarah', '2026-12-20', NOW());

-- Insert websites (7 records)
INSERT INTO websites (id, staff_id, domain, title, bio, social_links, status, created_at) VALUES
  ('web-001', 'staff-001', 'sarah-berkeley-chialpha.com', 'Chi Alpha at UC Berkeley with Sarah Johnson', 'Reaching Berkeley students with the Gospel through Bible study, prayer, and community.', '{"instagram":"@uchialpha","twitter":"@ChiAlphaBerkeley","facebook":"chialpha.berkeley"}', 'active', NOW()),
  ('web-002', 'staff-002', 'stanford-chialpha.org', 'Chi Alpha Stanford - Marcus Chen', 'Building Christ-centered community among Stanford students.', '{"instagram":"@stanfordchialpha","linkedin":"stanford-chi-alpha","facebook":"stanfordchialpha"}', 'active', NOW()),
  ('web-003', 'staff-003', 'ucla-chialpha-ministry.com', 'UCLA Chi Alpha - Jessica Rodriguez', 'Discipling UCLA Bruins to follow Jesus and impact their campus.', '{"instagram":"@uclachialpha","twitter":"@UCLAChiAlpha","tiktok":"@uclachialpha"}', 'active', NOW()),
  ('web-004', 'staff-004', 'norcal-chialpha-leadership.org', 'Northern California Chi Alpha Regional Office', 'Coordinating ministry leadership and vision across NorCal campuses.', '{"facebook":"chialpha.norcal","email":"norcal@chialpha.org"}', 'active', NOW()),
  ('web-005', 'staff-005', 'ucdavis-chialpha.net', 'Chi Alpha UC Davis - Emily Martinez', 'Growing disciples at UC Davis and training student leaders.', '{"instagram":"@ucdavischialpha","snapchat":"ucdavischialpha"}', 'active', NOW()),
  ('web-006', 'staff-006', 'sjsu-chialpha-community.com', 'SJSU Chi Alpha - James Thompson', 'Multiplying the Gospel impact at San Jose State University.', '{"instagram":"@sjsuchialpha","twitter":"@SJSUChiAlpha","tiktok":"@sjsuchialpha"}', 'active', NOW()),
  ('web-007', 'staff-007', 'uci-chialpha-fellowship.org', 'UCI Chi Alpha - Rachel Lee', 'An authentic Christian community at UC Irvine.', '{"instagram":"@ucichialpha","facebook":"uci.chialpha","youtube":"chialpha-uci"}', 'active', NOW());
