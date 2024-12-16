package funkin.api;

import haxe.Json;
import haxe.Http;

typedef User = {
	var login:String;
	var id:Int;
	var node_id:String;
	var avatar_url:String;
	var gravatar_id:String;
	var url:String;
	var html_url:String;
	var followers_url:String;
	var following_url:String;
	var gists_url:String;
	var starred_url:String;
	var subscriptions_url:String;
	var organizations_url:String;
	var repos_url:String;
	var events_url:String;
	var received_events_url:String;
	var type:String;
	var site_admin:Bool;
}

typedef Asset = {
	var url:String;
	var id:Int;
	var node_id:String;
	var name:String;
	@:optional var label:String;
	var uploader:User;
	var content_type:String;
	var state:String;
	var size:Int;
	var download_count:Int;
	var created_at:String;
	var updated_at:String;
	var browser_download_url:String;
}

typedef Reactions = {
	var url:String;
	var total_count:Int;
	var upvote:Int;
	var downvote:Int;
	var laugh:Int;
	var hooray:Int;
	var confused:Int;
	var heart:Int;
	var rocket:Int;
	var eyes:Int;
}

typedef Release = {
	var url:String;
	var assets_url:String;
	var upload_url:String;
	var html_url:String;
	var id:Int;
	var author:User;
	var node_id:String;
	var tag_name:String;
	var target_commitish:String;
	var name:String;
	var draft:Bool;
	var prerelease:Bool;
	var created_at:String;
	var published_at:String;
	var assets:Array<Asset>;
	var tarball_url:String;
	var zipball_url:String;
	var body:String;
	var reactions:Reactions;
}

enum abstract HttpReturnType(Int) from Int to Int
{
	var DATA = 0;
	var BYTES = 1;
}

typedef RepoInfo =
{
	var user:String;
	var repo:String;
}

class Github {
	// based on https://code.haxe.org/category/macros/add-git-commit-hash-in-build.html
	// pretty much gets the github repo lol
	public static macro function getCompiledRepoInfo()
	{
		var repoInfo:RepoInfo = {
			user: "riconuts", // default user
			repo: "FNF-Troll-Engine" // default repo
		}
		#if !display
		var process = null; 
		
		try{
			process = new sys.io.Process('git', ['config', '--get', 'remote.origin.url']);
		}
		catch (message){
			var pos = haxe.macro.Context.currentPos();
			haxe.macro.Context.warning("Cannot execute 'git config --get remote.origin.url'. " + 'Exception: "$message".' , pos);
			return macro $v{repoInfo};
		}

		if (process.exitCode() != 0)
		{
			var message = process.stderr.readAll().toString();
			var pos = haxe.macro.Context.currentPos();
			haxe.macro.Context.warning("Cannot execute 'git config --get remote.origin.url' " + message, pos);
			return macro $v{repoInfo};
		}

		// read the output of the process
		var originUrl:String = process.stdout.readLine();
		var sshRegex = ~/git@github.com:(.+)\/(.+).git/i;
		var urlRegex = ~/https:\/\/github.com\/(.+)\/(.+).git/i;

		var regex:EReg = null;

		if (sshRegex.match(originUrl))
			regex = sshRegex
		else if (urlRegex.match(originUrl))
			regex = urlRegex;

		if (regex != null)
		{
			repoInfo.user = regex.matched(1);
			repoInfo.repo = regex.matched(2);
		}

		// Generates a string expression
		return macro $v{repoInfo};
		#else
		// `#if display` is used for code completion. In this case returning an
		// empty string is good enough; We don't want to call git on every hint.
		return macro $v{repoInfo};
		#end
	}

	#if !macro
	static var redirects:Array<Int> = [
		301, 302, 308
	];
	static var baseURL:String = 'https://api.github.com/repos';
	static var defaultRepo:RepoInfo = Main.Version.githubRepo;
	public var requestURL:String = '';

	public function new(?repoInfo:RepoInfo){ 
		if (repoInfo == null)
			repoInfo = defaultRepo;
		requestURL = '$baseURL/${repoInfo.user}/${repoInfo.repo}';
	 }
	
	/*
	 * Gets all releases within the repo
	 *
	 * @param   filter				 A filter to apply to returned releases.
	 *
	 */
	public function getReleases(?filter:Release->Bool):Array<Release> {
		var returnedReleases:Array<Release> = [];
		try {
			var rawReleaseJSON:String = get("releases", ["accept" => "application/vnd.github+json"], [], DATA);
			if (rawReleaseJSON == null || rawReleaseJSON.length==0){
				trace("no data in releases!");
				return [];
			}
			var parsedReleaseJSON:Array<Dynamic> = Json.parse(rawReleaseJSON);
			if (parsedReleaseJSON==null){
				return [];
			}
			trace(parsedReleaseJSON.length);
			for(release in parsedReleaseJSON){
				// because +1 and -1 dont exist
				var reactions:Reactions = {
					url: Reflect.field(release.reactions, "url"),
					total_count: Reflect.field(release.reactions, "total_count"),
					upvote: Reflect.field(release.reactions, "+1"),
					downvote: Reflect.field(release.reactions, "-1"),
					laugh: Reflect.field(release.reactions, "laugh"),
					hooray: Reflect.field(release.reactions, "hooray"),
					confused: Reflect.field(release.reactions, "confused"),
					heart: Reflect.field(release.reactions, "heart"),
					rocket: Reflect.field(release.reactions, "rocket"),
					eyes: Reflect.field(release.reactions, "eyes"),
				}
				release.reactions = reactions; 
				var realRelease:Release = cast release;
				if (filter == null || filter(realRelease))returnedReleases.push(realRelease);
			}

		}
		return returnedReleases;
	}

	/*
	 * Sends a GET request to a specified API endpoint.
	 *
	 * @param   endpoint				The API endpoint to send a request to.
	 * @param	headers					A list of headers to be sent with the request.
	 * @param	params					A list of parameters to be sent with the request.
	 * @param	retType					What you want from the request, raw bytes or a string.
	 */
	public function get(endpoint:String, ?headers:Map<String, Dynamic>, ?params:Map<String, Dynamic>, ?retType:HttpReturnType){
		if (retType == null)
			retType = DATA;

		var daRequest = new Http('$requestURL/$endpoint');
		if (headers != null)
		{
			for (key => val in headers)
				daRequest.setHeader(key, val);
		}
		if (params != null)
		{
			for (key => val in params)
				daRequest.setParameter(key, val);
		}

		daRequest.setHeader("User-Agent", Main.UserAgent);


		var returned:Dynamic = null;

		switch (retType)
		{
			case DATA:
				daRequest.onData = function(d:Dynamic)
				{
					returned = d;
				}

			case BYTES:
				daRequest.onBytes = function(b:Dynamic)
				{
					returned = b;
				}

			default:
				trace("return type should be 0 or 1 (DATA or BYTES)");
		}

		daRequest.onError = function(e:Dynamic)
		{
			trace(e);
		}
		
		var tryRequest:Bool = true;
		daRequest.onStatus = function(code:Dynamic)
		{
			#if !js
			var responseHeaders = daRequest.responseHeaders;
			#else
			var responseHeaders = new haxe.ds.StringMap(); // TODO
			#end

			if (redirects.contains(code) && responseHeaders.exists("Location")){
				daRequest.url = responseHeaders.get("Location");
				trace("redirecT?? gonna try requesting " + daRequest.url);
				tryRequest = true;
			}else if(redirects.contains(code))
				trace("redirect with no location wtf??");
			
		}

		while (tryRequest){
			tryRequest = false;
			daRequest.request(false);
		}
		return returned;
	}

	/*
	 * Sends a POST request to a specified API endpoint.
	 *
	 * @param   endpoint				The API endpoint to send a request to.
	 * @param	post					The data to post to the endpoint
	 * @param	postType				How the data should be sent, as a string or as raw bytes.
	 * @param	headers					A list of headers to be sent with the request.
	 * @param	params					A list of parameters to be sent with the request.
	 * @param	retType					What you want from the request, raw bytes or a string.
	 */
	public function post(endpoint:String, post:Dynamic, ?postType:HttpReturnType, ?headers:Map<String, Dynamic>, ?params:Map<String, Dynamic>, ?retType:HttpReturnType)
	{
		if (postType == null)
			postType = DATA;
		if (retType == null)
			retType = DATA;

		var daRequest = new Http('$requestURL/$endpoint');
		if (headers != null)
		{
			for (key => val in headers)
				daRequest.setHeader(key, val);
		}
		if (params != null)
		{
			for (key => val in params)
				daRequest.setParameter(key, val);
		}

		daRequest.setHeader("User-Agent", Main.UserAgent);

		var returned:Dynamic = null;

		switch (postType){
			case DATA:
				daRequest.setPostData(post);
			case BYTES:
				daRequest.setPostBytes(post);
			default:
				trace("post type should be 0 or 1 (DATA or BYTES)");
				return null;
		}

		switch (retType){
			case DATA:
				daRequest.onData = function(d:Dynamic){
					returned = d;
				}
				
			case BYTES:
				daRequest.onBytes = function(b:Dynamic){
					returned = b;
				}
				
			default:
				trace("return type should be 0 or 1 (DATA or BYTES)");
		}


		daRequest.onError = function(e:Dynamic){
			trace(e);
		}

		var tryRequest:Bool = true;
		daRequest.onStatus = function(code:Dynamic)
		{
			#if !js
			var responseHeaders = daRequest.responseHeaders;
			#else
			var responseHeaders = new haxe.ds.StringMap(); // TODO
			#end

			if (redirects.contains(code) && responseHeaders.exists("Location"))
			{
				daRequest.url = responseHeaders.get("Location");
				trace("redirecT?? gonna try requesting " + daRequest.url);
				tryRequest = true;
			}
			else if (redirects.contains(code))
				trace("redirect but the code doesnt have a location, weird!!");
			
		}

		while (tryRequest)
		{
			tryRequest = false;
			daRequest.request(true);
		}

		return returned;
	}

	#end
}