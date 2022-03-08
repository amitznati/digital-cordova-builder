
/**
 * Using Rails-like standard naming convention for endpoints.
 * POST    /users/broadcastAction   ->  broadcastAction
 */
// const axios = require('axios');
// const _ = require('lodash');
const createNewApp = require('../../../grunt/tasks/utils');


exports.submitBuild = async (req, res) => {
    console.log(req.body);
    console.log(req.files);
    console.log(req.file);
    const jobId = req.file.filename.split('.')[1];
    createNewApp(jobId);
    res.json({jobId});
};
