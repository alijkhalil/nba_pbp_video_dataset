#!/bin/sh

# Check number of parameters
if [ $# -lt 1 ]; then
	echo "Must supply a URL (and an optional SOCKS port) pointing the JSON object."
	exit 1
fi


# Add curl command options
CURL_OPTS="--max-time 25 --retry 25 --retry-delay 5 --retry-max-time 750" 
if [ $# -eq 2 ]; then
    CURL_OPTS="$CURL_OPTS --socks5 localhost:$2"
fi


# Actually execute curl command
curl $CURL_OPTS $1 -H 'Pragma: no-cache' -H 'Accept-Encoding: gzip, deflate, sdch' -H 'Accept-Language: en-US,en;q=0.8' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Cache-Control: no-cache' -H 'Cookie: __gads=ID=27e6c5f6bdbd8be7:T=1495247373:S=ALNI_MaR1x3mIZ3HS1PMV1LOJm0AE4hhJQ; TSid=G3b041425-ad37-401b-8470-97adbe5f5f59; authid=1511452840-usr-b3207c51445120aed5c736d6ed52245f; umbel_browser_id=aa20d122-d861-4d4d-9f95-28c2accf6377; AMCV_7FF852E2556756057F000101%40AdobeOrg=817868104%7CMCIDTS%7C17171%7CMCMID%7C50890769043922187912411641470913481365%7CMCAAMLH-1483581609%7C7%7CMCAAMB-1484178925%7CNRX38WO0n5BH8Th-nqAG_A%7CMCOPTOUT-1483581325s%7CNONE%7CMCAID%7CNONE; SSLB=1; SSID2=CAADeh0AAAAAAAAQW_xYA4ABAhBb_FgBAAAAAAAAAAAAEFv8WAChxw; SSSC=10.G6412100093780000771.1|0.0; SSPV=EMAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAA; ASP.NET_SessionId=z31wsjw2je550s4ylgdxdbuz; globalUserOrderId=Id=; bSID=Id=21780158-b041-4551-affb-29c3b8f090db; SSRT=EFv8WAADAQ; mmapi.store.p.0=%7B%22mmparams.d%22%3A%7B%7D%2C%22mmparams.p%22%3A%7B%22pd%22%3A%221524469394323%7C%5C%221682316271%7CAQAAAAoBQgwz7Sa1Dgir2ZoBAPmyQWUcitRIDwAAAPmyQWUcitRIAAAAAP%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FAAZEaXJlY3QBtQ4BAAAAAAAAAAEAAP%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwIAeUgAAABJu1eOtQ4A%2F%2F%2F%2F%2FwG1DrUO%2F%2F8BAAABAAAAAAHesQAAzhkBAAD4UwAAAIXIPUK1DgD%2F%2F%2F%2F%2FAbUOtQ7%2F%2FwEAAAEAAAAAAffLAAABRAEAAAAAAAFF%5C%22%22%2C%22srv%22%3A%221524469394327%7C%5C%22nycvwcgus10%5C%22%22%7D%7D; mmapi.store.s.0=%7B%22mmparams.d%22%3A%7B%7D%2C%22mmparams.p%22%3A%7B%7D%7D; optimizelySegments=%7B%223713124431%22%3A%22gc%22%2C%223728264737%22%3A%22referral%22%2C%223734713784%22%3A%22false%22%2C%223735704323%22%3A%22none%22%7D; optimizelyEndUserId=oeu1482828772374r0.18870268999116324; optimizelyBuckets=%7B%7D; ug=5806c36c070cdb0a3c8ef702cb019b0c; ugs=1; AkamaiAnalytics_VisitUnqueTitles=; octowebstatid=vx6oyud7oqo1xdwxt1cm; AkamaiAnalyticsDO_visitStartTime=1495154952332; AkamaiAnalytics_VisitCookie=1; AkamaiAnalytics_BrowserSessionId=564DE09CAEBF18248F50B64C8990844C9F05A195; AkamaiAnalyticsDO_bitRateBucketsCsv=0,0,0,0,0,26195,0,0,0; AkamaiAnalyticsDO_visitMetricsCsv=1|1|1|1|0|33295|26195|26037|0|0|4|0|0|0|0; AkamaiAnalytics_VisitIsPlaying=0; AkamaiAnalytics_VisitLastCloseTime=1495154985635; personalize=%7B%7D; nbaMembershipInfo=%7B%22tid%22%3A%223b041425-ad37-401b-8470-97adbe5f5f59%22%2C%22email%22%3A%22alijkhalil@gmail.com%22%2C%22identityType%22%3A%22EMAIL%22%2C%22entitlements%22%3A%5B%22lpbc%22%2C%22lprdo%22%5D%2C%22teams%22%3A%5B%22GSW%22%5D%7D; s_cc=true; s_fid=20BDE3422A8E23B9-0CAE67E4CF05DADC; s_sq=%5B%5BB%5D%5D; s_vi=[CS]v1|2C23A1DB8519186F-4000060AA00069C6[CE]; _ga=GA1.2.1248399410.1490590180; _gid=GA1.2.1913566401.1495166448; crtg_trnr=' -H 'Connection: keep-alive' --compressed 2>/dev/null


# Return curl's exit status
exit $?