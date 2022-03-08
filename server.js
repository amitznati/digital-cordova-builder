// BASE SETUP
// =============================================================================

// call the packages we need
import express from 'express';
const app = express();
import bodyParser from 'body-parser';
// import path from 'path';
// import _ from 'lodash';
import routes from './src/routes';
// import config from './src/config';


// configure app
// app.use(morgan('dev')); // log requests to the console

// apply headers
app.use((req, res, next) => {
	if (process.env.NODE_ENV == "development") {
		res.header('Cache-Control', 'private, no-cache, no-store, must-revalidate');
		res.header('Expires', '-1');
		res.header('Pragma', 'no-cache');
	}
	res.header('Access-Control-Allow-METHODS', 'GET,PUT,POST,DELETE,HEAD,OPTIONS');
	res.header('Access-Control-Allow-Origin', '*');
	res.header('Access-Control-Allow-Headers', "X-ACCESS_TOKEN, Access-Control-Allow-Origin, Authorization, Origin, x-requested-with, Content-Type, Content-Range, Content-Disposition, Content-Description");
	next();
});

// configure body parser
app.use(bodyParser.urlencoded({extended: true}));
app.use(bodyParser.json());
let port = 8080;
console.log(process.env.NODE_ENV);

if (process.env.NODE_ENV === 'development') {
	port = 7000; // set our port
}


// REGISTER OUR ROUTES -------------------------------
routes.default(app);

app.set('etag', false);
// START THE SERVER
// =============================================================================
app.listen(port);

console.log('Magic happens on port ' + port);

// uncaughtException
process.on('uncaughtException', (err) => {
	console.log(err);
})
