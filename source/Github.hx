package;

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
    var label:String;
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
	var tarball_url:String;
	var zipball_url:String;
	var body:String;
	var reactions:Reactions;
}

@:enum abstract HttpReturnType(Int) from Int to Int
{
    var DATA = 0;
	var BYTES = 1;
}

class Github {
    static var baseURL:String = 'https://api.github.com/repos';
    static var defaultUser = Main.githubRepo.user;
    static var defaultRepo = Main.githubRepo.repo;
    var requestURL:String = '';
    public function new(?user:String, ?repo:String){ 
        if(user == null)user = defaultUser;
		if (repo == null)repo = defaultRepo;
		requestURL = '$baseURL/$user/$repo';
     } // TODO: maybe make it so you can specify token n shit
    // rn doesnt matter tho cus this'll only be used for gathering releases for troll engine
    
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
				returnedReleases.push(realRelease);
            }

        }
        return returnedReleases;
    }

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
			throw e;
		}
		
		var tryRequest:Bool = true;
		daRequest.onStatus = function(code:Dynamic)
		{
			if (code == 301 && daRequest.responseHeaders.exists("Location")){
				daRequest.url = daRequest.responseHeaders.get("Location");
				trace("redirecT?? gonna try requesting " + daRequest.url);
				tryRequest = true;
			}
		}

		while (tryRequest){
			tryRequest = false;
			daRequest.request(false);
		}
		return returned;
    }

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
            throw e;
        }

        daRequest.request(true);

		return returned;
	}


}