const {Router} = require('express');

const controller = require('./update.controller');

var router = new Router();


router.get('/getLatestVersionByAppId', controller.getLatestVersionByAppId);



module.exports = router;