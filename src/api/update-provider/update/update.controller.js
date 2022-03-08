/**
 * Using Rails-like standard naming convention for endpoints.
 * POST    /users/broadcastAction   ->  broadcastAction
 */
const axios = require('axios');
const _ = require('lodash');
import Utils from '../utils';



exports.getLatestVersionByAppId = async (req, res) => {
   const {appId, currentVersion} = req.query;
    console.log(appId);
    const NEXUS_URL = `http://localhost:8081/repository/maven-releases/${appId}/${appId}/maven-metadata.xml`;
    const updateResponse = {isUpdateAvailable: false};
    var config = {
        headers: {'Content-Type': 'text/xml', 'Accept': 'application/xml'},
        responseType: "document"
    };
    let response = await axios.get(NEXUS_URL, config);
    response = await (Utils.parseXml(response.data.toString()));
    console.log(response);
    var latestVersion = response.metadata.versioning[0].latest[0];
    console.log(latestVersion);
    if (latestVersion !== currentVersion) {
        updateResponse.isUpdateAvailable = true;
        updateResponse.latestVersion = latestVersion;
        updateResponse.downloadURL = `http://10.0.0.8:8081/repository/maven-releases/${appId}/${appId}/${latestVersion}/${appId}-${latestVersion}.zip`;
    }
    res.json(updateResponse);

};
