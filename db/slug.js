db.Team.find().forEach(function(t) {
  t.slug = t.name.toLowerCase().replace(/\W+/g, '-');
  db.Team.save(t);
});

db.Team.ensureIndex({ slug: 1 });
