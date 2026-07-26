-- Third tenant security level: viewer = read-only member.
alter type user_role add value if not exists 'viewer';
