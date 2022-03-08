const {Router} = require('express');
const multer  = require('multer');
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads');
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + 'T' + Math.round(Math.random() * 1E9);
        cb(null, file.fieldname + '.' + uniqueSuffix + '.zip');
    }
});

const upload = multer({ storage: storage });
const controller = require('./build.controller');

var router = new Router();


router.post('/submitBuild', upload.single('configFile'), controller.submitBuild);



module.exports = router;
