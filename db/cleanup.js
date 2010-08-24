function pp(a) {
  if (a.forEach) a.forEach(printjson)
  else printjson(a)
}

// lowercase emails
print("--- uppercase letter in email:");
pp(db.Person.find({email:/[A-Z]/}, {email:1}));
print("--- downcasing");
db.Person.find({email:/[A-Z]/}).forEach(function(p) { p.email = p.email.toLowerCase(); db.Person.save(p) });
print("--- post-downcase uppercase letter in email total:");
pp(db.Person.count({email:/[A-Z]/}));

// fix Tj email
print("--- tweaking tj's email");
pp(db.Person.find({ name: 'Tj Holowaychuk' }, { name: 1, email: 1 }));
db.Person.update({ name: 'Tj Holowaychuk' }, { $set: { email: 'tj@vision-media.ca' } }, false, false)
pp(db.Person.find({ name: 'Tj Holowaychuk' }, { name: 1, email: 1 }));

// find dupes
function countDupes() {
  return db.Person.group({
      key: { email: true },
      initial: { count: 0 },
      reduce: function(obj, prev) { prev.count += 1; } })
    .filter(function(g) { return g.count > 1; });
}

function findDupes() {
  return db.Person.find({
    email: { $in: countDupes()
      .map(function(g) { return g.email; }) } },
    { type: 1, email: 1 })
    .sort({ email: 1 })
    .map(function(p) {
      p.teams = db.Team.find({ 'members._id': p._id },
        { name: 1 }).map(function(m) { return m.name; });
      return p; });
}

// remove duplicate emails
dupes = findDupes()
invalid = dupes.filter(function(d) { return d.type == 'Participant' && !d.teams.length })
print("--- duplicates:");
pp(dupes)

print("--- duplicate stats:");
pp({ dupes: dupes.length, invalid: invalid.length, people: db.Person.count() })
db.Person.remove({ _id: { $in: invalid.map(function(i) { return i._id; }) } })
print("--- post-remove duplicate stats:");
pp({ dupes: findDupes(), people: db.Person.count() })

// clear votes
print("--- clearing votes");
db.Vote.remove({})

// ensure uniqueness at the db level
print("--- creating indexes");
db.Person.ensureIndex({email: 1}, {unique: true});
db.Team.ensureIndex({slug: 1}, {unique: true});
db.Vote.ensureIndex({'team._id': 1, 'person._id': 1}, {unique: true});

// other misc indexes
db.Vote.ensureIndex({'team._id': 1 });
db.Vote.ensureIndex({'person._id': 1 });
