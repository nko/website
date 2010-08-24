// mongo nodeknockout ../public/javascripts/json2.js github.js | tail +5 | python -mjson.tool

var teams = db.Team.find().map(function(t) {
  return {
    id: t._id.str,
    name: t.name,
    slug: t.slug,
    members: t.members.map(function(m) {
      var p = db.Person.findOne({ _id: m._id }, {
        github: true, email: true, name: true
      });
      delete p._id;

      return p;
    })
  };
});

print(JSON.stringify(teams));
