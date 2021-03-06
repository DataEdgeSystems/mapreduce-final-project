REGISTER file:/home/hadoop/lib/pig/piggybank.jar
DEFINE CSVLoader org.apache.pig.piggybank.storage.CSVLoader;
SET default_parallel 10;

-- Load the users, networks and tweets dataset
users= LOAD 's3://mrprojectsarika/samplenew.txt' using PigStorage(',') AS
(userId,userName,friendCount:int,followerCount:int,statusCount:int,favoriteCount:int,accountAge,city,state,longitude,latitude);
networks= LOAD 's3://mrprojectsarika/network.txt' using PigStorage(',') AS (followerId, friendId);
tweets= LOAD 's3://mrprojectsarika/tweets.txt' using PigStorage(',') AS (tuserId, status,originalText, copyText,link,tweetId,time,retweetCount:int,favorite,mentionedUserId,hashTags);

-- project the users dataset to set the longitude value to positive
projectedUsers= FOREACH users GENERATE userId,userName,friendCount,followerCount,statusCount,favoriteCount,state,-longitude AS timeZone;

-- Join the projected users dataset with Networks dataset and the resulting table with the tweets dataset
joinUsersAndNetworks= JOIN projectedUsers BY (userId), networks BY (followerId);
joinFollowersAndTweets= JOIN joinUsersAndNetworks BY (userId), tweets by (tuserId);

-- Project the joined table to generate only the columns required to generate the character
projectedJoin= FOREACH joinFollowersAndTweets GENERATE joinUsersAndNetworks::projectedUsers::userId AS userId, joinUsersAndNetworks::projectedUsers::friendCount AS friendCount, joinUsersAndNetworks::projectedUsers::followerCount AS followerCount, joinUsersAndNetworks::projectedUsers::statusCount AS statusCount, joinUsersAndNetworks::projectedUsers::favoriteCount AS favoriteCount, joinUsersAndNetworks::projectedUsers::state AS state,joinUsersAndNetworks::projectedUsers::timeZone AS timeZone, tweets::retweetCount AS retweetCount;

-- filter the projectedJoin according to the longitude values
filterCentral= FILTER projectedJoin BY timeZone>75 AND timeZone< 105;
filterEast= FILTER projectedJoin BY timeZone<75;
filterMountain= FILTER projectedJoin BY timeZone>105 AND timeZone< 120;
filterPacific= FILTER projectedJoin BY timeZone>120;

-- group the filtered table on the state
groupCentral= GROUP filterCentral BY (state);
groupEast= GROUP filterEast BY (state);
groupMountain= GROUP filterMountain BY (state);
groupPacific= GROUP filterPacific BY (state);

-- perform aggregation function on columns to determine the character of each state in each time zone
characterCentral= FOREACH groupCentral GENERATE group, MAX(filterCentral.retweetCount),AVG(filterCentral.friendCount),AVG(filterCentral.followerCount),AVG(filterCentral.favoriteCount), AVG(filterCentral.statusCount);;
characterEast= FOREACH groupEast GENERATE group, MAX(filterEast.retweetCount),AVG(filterEast.friendCount),AVG(filterEast.followerCount),AVG(filterEast.favoriteCount), AVG(filterEast.statusCount);;
characterMountain= FOREACH groupMountain GENERATE group, MAX(filterMountain.retweetCount),AVG(filterMountain.friendCount),AVG(filterMountain.followerCount),AVG(filterMountain.favoriteCount), AVG(filterMountain.statusCount);;
characterPacific= FOREACH groupPacific GENERATE group, MAX(filterPacific.retweetCount),AVG(filterPacific.friendCount),AVG(filterPacific.followerCount),AVG(filterPacific.favoriteCount), AVG(filterPacific.statusCount);;

-- Store the results in separate output folders 
STORE characterCentral INTO 's3://mrprojectsarika/outputJPF/central' USING PigStorage(',');
STORE characterEast INTO 's3://mrprojectsarika/outputJPF/east' USING PigStorage(',');
STORE characterMountain INTO 's3://mrprojectsarika/outputJPF/mountain' USING PigStorage(',');
STORE characterPacific INTO 's3://mrprojectsarika/outputJPF/pacific' USING PigStorage(',');
