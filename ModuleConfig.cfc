/**
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 */
component {

    // Module Properties
    this.title 				= "stachebox";
    this.author 			= "Ortus Solutions";
    this.webURL 			= "https://github.com/coldbox-modules/stachebox";
    this.description 		= "A Logstash and Bug Management Platform for Coldbox";

    // Model Namespace
	this.modelNamespace		= "stachebox";

	this.entrypoint         = "stachebox";

    // CF Mapping
    this.cfmapping			= "stachebox";

    // Dependencies
	this.dependencies 		= [ "cbelasticsearch", "logstash", "cbrestbasehandler", "cbsecurity", "cbvalidation", "mementifier", "JSONToRC" ];

	// App Helpers
	this.applicationHelper = [
		"models/mixins/elixirPath.cfm"
	];

    /**
     * Configure Module
     */
    function configure(){
		var applicationName = server.coldfusion.productname == "Lucee" ? getApplicationSettings().name : getApplicationMetadata().name;

        settings = {
			"settingsIndex" : getSystemSetting( "STACHEBOX_SETTINGS_INDEX", ".stachebox_settings" ),
			"usersIndex" : getSystemSetting( "STACHEBOX_USERS_INDEX", ".stachebox_users" ),
			"logIndexPattern" : "logstash-*",
			"adminEmail" : getSystemSetting( "STACHEBOX_ADMIN_EMAIL", "" ),
			"adminPassword" : getSystemSetting( "STACHEBOX_ADMIN_PASSWORD", "" ),
			"isStandalone" : false,
			"cbsecurity" : {
				"userService" : "UserService@stachebox",
				// Module Relocation when an invalid access is detected, instead of each rule declaring one.
				"invalidAuthenticationEvent" 	: "stachebox:api.v1.BaseAPIHandler.onAuthenticationFailure",
				// Default Auhtentication Action: override or redirect when a user has not logged in
				"defaultAuthenticationAction"	: "override",
				// Module override event when an invalid access is detected, instead of each rule declaring one.
				"invalidAuthorizationEvent"		: "stachebox:api.v1.BaseAPIHandler.onAuthorizationFailure",
				// Default Authorization Action: override or redirect when a user does not have enough permissions to access something
				"defaultAuthorizationAction"	: "override",
				// You can define your security rules here
				"rules"							: [],
				"jwt" : {
					"customAuthHeader" : "x-auth-token",
					"expiration"       : 20,
				}
			}
		};

        // Try to look up the release based on a box.json
        if( !isNull( appmapping ) ) {
            var boxJSONPath = expandPath( '/' & appmapping & '/box.json' );
            if( fileExists( boxJSONPath ) ) {
                var boxJSONRaw = fileRead( boxJSONPath );
                if( isJSON( boxJSONRaw ) ) {
                    var boxJSON = deserializeJSON( boxJSONRaw );
                    if( boxJSON.keyExists( 'version' ) ) {
                        settings.release = boxJSON.version;
                        if( boxJSON.keyExists( 'slug' ) ) {
                            settings.release = boxJSON.slug & '@' & settings.release;
                        } else if( boxJSON.keyExists( 'name' ) ) {
                            settings.release = boxJSON.name & '@' & settings.release;
                        }
                    }
                }
            }
        }

        interceptors = [
            { class="stachebox.interceptors.Stachebox" },
            { class="stachebox.interceptors.TokenAuthentication" },
            { class="stachebox.interceptors.BasicAuthentication" }
		];

		resources = [
			{
				resource : "/api/v1/logs",
				handler : "api.v1.Logs"

			},
			{
				resource : "/api/v1/users",
				handler : "api.v1.Users"

			}
		];

		routes = [
			{
				pattern : "/api/v1/authentication",
				handler : "api.v1.Authentication",
				action : {
					"HEAD" : "check",
					"POST" : "login",
					"DELETE" : "logout"
				}
			},
			{ pattern = "/", handler = "Main", action = "index" },
			// Convention Route
			{ pattern="(.*?)", handler = "Main", action = "index" }
		];

    }

    /**
     * Fired when the module is registered and activated.
     */
    function onLoad(){
		// Append any persisted settings
		application.wirebox.getInstance( "SearchBuilder@cbelasticsearch" )
					.new( settings.settingsIndex )
					.setQuery( { "match_all" : {} })
					.execute()
					.getHits()
					.each( function( doc ){
						var setting = doc.getMemento();
						if( structKeyExists( setting, "key" ) ){
							settings[ setting.key ] = settings[ setting.value ];
						}
					} )

	}

    /**
     * Fired when the module is unregistered and unloaded
     */
	function onUnload(){}


}
