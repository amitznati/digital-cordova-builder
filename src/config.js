
const config = {
	JWT_SECRET: "OFIRISTHEBEST",
	server: {
		port: process.env.PORT || 8080
	},
	websocket: {
		port: process.env.WS_PORT || 3030
	}

};

module.exports = config;