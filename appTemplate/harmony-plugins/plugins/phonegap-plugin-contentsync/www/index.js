	/* global cordova:false */
	
	/*!
	 * Module dependencies.
	 */
	
	var exec = cordova.require('cordova/exec');
	
	/**
	 * ContentSync constructor.
	 *
	 * @param {Object} options to initiate a new content synchronization.
	 *   @param {String} src is a URL to the content sync end-point.
	 *   @param {String} id is used as a unique identifier for the sync operation
	 *   @param {Object} type defines the sync strategy applied to the content.
	 *     @param {String} replace completely removes existing content then copies new content.
	 *     @param {String} merge   does not modify existing content, but adds new content.
	 *   @param {Object} headers are used to set the headers for when we send a request to the src URL
	 *  @param {Boolean} validateSrc whether to validate src url with a HEAD request before download (ios only, default true).
	 * @return {ContentSync} instance that can be monitored and cancelled.
	 */
	
	var ContentSync = function(options) {
		this._handlers = {
			'progress': [],
			'cancel': [],
			'error': [],
			'complete': []
		};
	
		// require options parameter
		if (typeof options === 'undefined') {
			throw new Error('The options argument is required.');
		}
	
		// require options.src parameter
		if (typeof options.src === 'undefined' && options.type !== "local") {
			throw new Error('The options.src argument is required for merge replace types.');
		}
	
		// require options.id parameter
		if (typeof options.id === 'undefined') {
			throw new Error('The options.id argument is required.');
		}
	
		// define synchronization strategy
		//
		//     replace: This is the normal behavior. Existing content is replaced
		//              completely by the imported content, i.e. is overridden or
		//              deleted accordingly.
		//     merge:   Existing content is not modified, i.e. only new content is
		//              added and none is deleted or modified.
		//     local:   Existing content is not modified, i.e. only new content is
		//              added and none is deleted or modified.
		//
		if (typeof options.type === 'undefined') {
			options.type = 'replace';
		}
	
		if (typeof options.headers === 'undefined') {
			options.headers = null;
		}
	
		if (typeof options.copyCordovaAssets === 'undefined') {
			options.copyCordovaAssets = false;
		}
	
		if (typeof options.copyRootApp === 'undefined') {
			options.copyRootApp = false;
		}
	
		if (typeof options.timeout === 'undefined') {
			options.timeout = 15.0;
		}
	
		if (typeof options.trustHost === 'undefined') {
			options.trustHost = false;
		}
	
		if (typeof options.manifest === 'undefined') {
			options.manifest = "";
		}
	
		if (typeof options.validateSrc === 'undefined') {
			options.validateSrc = true;
		}
	
		// store the options to this object instance
		this.options = options;
	
		// triggered on update and completion
		var that = this;
		var success = function(result) {
			if (result && typeof result.progress !== 'undefined') {
				that.emit('progress', result);
			} else if (result && typeof result.localPath !== 'undefined') {
				that.emit('complete', result);
			}
		};
	
		// triggered on error
		var fail = function(msg) {
			var e = (typeof msg === 'string') ? new Error(msg) : msg;
			that.emit('error', e);
		};
	
		// wait at least one process tick to allow event subscriptions
		setTimeout(function() {
			exec(success, fail, 'Sync', 'sync', [options.src, options.id, options.type, options.headers, options.copyCordovaAssets, options.copyRootApp, options.timeout, options.trustHost, options.manifest, options.validateSrc]);
		}, 10);
	};
	
	/**
	 * Cancel the Content Sync
	 *
	 * After successfully canceling the content sync process, the `cancel` event
	 * will be emitted.
	 */
	
	ContentSync.prototype.cancel = function() {
		var that = this;
		var onCancel = function() {
			that.emit('cancel');
		};
		setTimeout(function() {
			exec(onCancel, onCancel, 'Sync', 'cancel', [ that.options.id ]);
		}, 10);
	};
	
	/**
	 * Listen for an event.
	 *
	 * The following events are supported:
	 *
	 *   - progress
	 *   - cancel
	 *   - error
	 *   - completion
	 *
	 * @param {String} eventName to subscribe to.
	 * @param {Function} callback triggered on the event.
	 */
	
	ContentSync.prototype.on = function(eventName, callback) {
		if (this._handlers.hasOwnProperty(eventName)) {
			this._handlers[eventName].push(callback);
		}
	};
	
	/**
	 * Emit an event.
	 *
	 * This is intended for internal use only.
	 *
	 * @param {String} eventName is the event to trigger.
	 * @param {*} all arguments are passed to the event listeners.
	 *
	 * @return {Boolean} is true when the event is triggered otherwise false.
	 */
	
	ContentSync.prototype.emit = function() {
		var args = Array.prototype.slice.call(arguments);
		var eventName = args.shift();
	
		if (!this._handlers.hasOwnProperty(eventName)) {
			return false;
		}
	
		for (var i = 0, length = this._handlers[eventName].length; i < length; i++) {
			this._handlers[eventName][i].apply(undefined,args);
		}
	
		return true;
	};
	
	/*!
	 * Content Sync Plugin.
	 */
	
	module.exports = {
		/**
		 * Synchronize the content.
		 *
		 * This method will instantiate a new copy of the ContentSync object
		 * and start synchronizing.
		 *
		 * @param {Object} options
		 * @return {ContentSync} instance
		 */
	
		sync: function(options) {
			return new ContentSync(options);
		},
	
		/**
		 * Unzip
		 *
		 * This call is to replicate Zip::unzip plugin
		 *
		 */
	
		unzip: function(fileUrl, dirUrl, callback, progressCallback) {
			var win = function(result) {
				if (result && result.progress) {
					if (progressCallback) {
						progressCallback(result);
					}
				} else if (callback) {
					callback(0);
				}
			};
			var fail = function(result) {
				if (callback) {
					callback(-1);
				}
			};
			exec(win, fail, 'Zip', 'unzip', [fileUrl, dirUrl]);
		},
	
		/**
		 * Download
		 *
		 * This call is to replicate nothing but might be used instead of FileTransfer
		 *
		 */
	
		download: function(url, headers, cb) {
			var callback = (typeof headers == "function" ? headers : cb);
			exec(callback, callback, 'Sync', 'download', [url, null, headers]);
		},
		
		/**
		 * loadUrl
		 *
		 * This method allows loading file:// urls when using WKWebViews on iOS. 
		 *
		 */
	
		loadUrl: function(url, cb) {
			if(!url) {
				throw new Error('URL is required.');
			}
			exec(cb, cb, 'Sync', 'loadUrl', [url]);
		},
	
		pullContentUpdate: function(appId, url) {
			return new Promise((resolve, reject) => {
				var sync = new ContentSync({ src: url, id: appId, type: 'merge', copyCordovaAssets: true, copyRootApp: true, headers: false, trustHost: true });
			
				sync.on('progress', function(progress) {
					SpinnerDialog.show("Updating Content", `Progress: ${progress.progress}%`, true);
					console.log("Progress event", progress);
				});
				sync.on('complete', function(data) {
					console.log("Complete", data);
					SpinnerDialog.hide();
					
					resolve(true);
				});
			
				sync.on('error', function(e) {
					console.log("There is no update available");
					if(error) {
						resolve(false);
					}
				});
			});
		},
		
		checkLocalSync: function(appId) {
			return new Promise((resolve, reject) => {
				console.log(sessionStorage.getItem("localContentLoaded"));
				if(sessionStorage.getItem("localContentLoaded")) {
					if(sessionStorage.getItem("setServerPath")) {
						sessionStorage.removeItem("setServerPath");
						location.reload();
					}
					resolve(true);
					return;
				}
				var checkLocalSync = new ContentSync({id: appId, type: 'local'});
				checkLocalSync.on('complete', function(data) {
					console.log(data);
					if(data.localPath) {
						sessionStorage.setItem("localContentLoaded", 1);
						
						if(cordova.platformId === "android") {
							Ionic.WebView.setServerBasePath(data.localPath);
							sessionStorage.setItem("setServerPath", 1);
	
						} 
						else if (cordova.platformId === "ios") {
							Ionic.WebView.setServerBasePath(appId);
							sessionStorage.setItem("setServerPath", 1);
							
						}
						resolve(data.localPath);
					}
				});
				checkLocalSync.on('error', (e) => {
					if(!sessionStorage.getItem("localContentLoaded") && cordova.platformId === "android") {
						this.checkLocalSync(appId);
					}
					resolve(false);
				});
			});
			
		},
		checkUpdate: function() {
			Ionic.WebView.getUserConfiguration((data) => {
				if(cordova.platformId === "android") {
					data = JSON.parse(data);
				} 
				
				var isUpdateEnabled = data.contentUpdateEnabled == 'true';
				if (!isUpdateEnabled) {
					return;
				}
				var appId = data.appId;
				var url = data.contentUpdateURL;
				var currentAppVersion = localStorage.getItem("currentAppVersion");
				currentAppVersion = currentAppVersion || "1.0.0";
				if(currentAppVersion) {
					SpinnerDialog.show("Content", `Checking for update`, true);
					setTimeout(SpinnerDialog.hide, 2000);
					this.isAvailableUpdate(
							url,
							appId,
							currentAppVersion
						).then( (data) => {
							console.log(data);
							if(data && data.isUpdateAvailable) {
								SpinnerDialog.show("Content", `There is new update, please hold on.`, true);
								this.pullContentUpdate(appId, data.downloadURL).then( () => {
									localStorage.setItem("currentAppVersion", data.latestVersion);
									console.log(this);
									console.log("Fetching local content");
									this.checkLocalSync(appId).then((data) => {
										SpinnerDialog.hide();
									});
									
									
								});   
							} else {
								this.checkLocalSync(appId).then((data) => {
									SpinnerDialog.hide();
									
								});
							}
						});
				}
			});
		},
		isAvailableUpdate: function(url, appId, versionToCompare) {
			return new Promise((resolve, reject) => {
				var xhr = new XMLHttpRequest;
				url = url + '?appId='+appId + '&currentVersion='+versionToCompare;
				console.log(url);
				xhr.open('GET', url, true);
		
				// If specified, responseType must be empty string or "document"
				xhr.responseType = 'json';
		
		
				xhr.onload = function () {
					if (xhr.readyState === xhr.DONE && xhr.status === 200) {
						console.log(xhr.response);
						var response = (xhr.response);
						console.log(response);
						if (response.isUpdateAvailable) {
							resolve(response);
						} else {
							resolve(false);
						}
					}
				};
				xhr.send();
			});
		},
		/**
		 * ContentSync Object.
		 *
		 * Expose the ContentSync object for direct use
		 * and testing. Typically, you should use the
		 * .sync helper method.
		 */
	
		ContentSync: ContentSync,
	
		/**
		 * PROGRESS_STATE enumeration.
		 *
		 * Maps to the `progress` event's `status` object.
		 * The plugin user can customize the enumeration's mapped string
		 * to a value that's appropriate for their app.
		 */
	
		PROGRESS_STATE: {
			0: 'STOPPED',
			1: 'DOWNLOADING',
			2: 'EXTRACTING',
			3: 'COMPLETE'
		},
	
		/**
		 * ERROR_STATE enumeration.
		 *
		 * Maps to the `error` event's `status` object.
		 * The plugin user can customize the enumeration's mapped string
		 * to a value that's appropriate for their app.
		 */
	
		ERROR_STATE: {
			1: 'INVALID_URL_ERR',
			2: 'CONNECTION_ERR',
			3: 'UNZIP_ERR'
		}
	};
	
	
	/*
	function checkUpdate() {
		var appId = "myapp";
		var url = "http://10.18.1.229:7000/api/update-provider/getLatestVersionByAppId";
		var currentAppVersion = localStorage.getItem("currentAppVersion");
		currentAppVersion = currentAppVersion || "1.0.0";
		if(currentAppVersion) {
			SpinnerDialog.show("Content", `Checking for update`, true);
			setTimeout(SpinnerDialog.hide, 2000);
			ContentSync.isAvailableUpdate(
					url,
					appId,
					currentAppVersion
				).then(function (data) {
					console.log(data);
					if(data && data.isUpdateAvailable) {
						SpinnerDialog.show("Content", `There is new update, please hold on.`, true);
						ContentSync.pullContentUpdate(appId, data.downloadURL).then( () => {
							localStorage.setItem("currentAppVersion", data.latestVersion);
								ContentSync.checkLocalSync(appId).then((data) => {
								SpinnerDialog.hide();
							});
							
						});   
					} else {
						ContentSync.checkLocalSync(appId).then((data) => {
							SpinnerDialog.hide();
							
						});
					}
				});
		}
	}
	*/
	
	
	