/**
 * Main application routes
**/
var baseAPI = '/api';
exports.default = function(app) {

app.use(baseAPI+'/update-provider', require('../api/update-provider/update'));
app.use(baseAPI+'/build-provider', require('../api/build-provider/build'));

// LASTLINE

};
