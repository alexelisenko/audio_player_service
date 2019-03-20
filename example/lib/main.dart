import 'package:audio_player_service/audio_player.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:audio_player_service/audio_player_service.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AudioPlayer audioPlayer;
  AudioPlayerState playerState;
  Duration currentPosition;
  int itemIndex;
  AudioPlayerItem currentItem;

  List<AudioPlayerItem> getItems(){
    List<AudioPlayerItem> items = [];
    
    items.add(AudioPlayerItem(
      url: "https://api.soundcloud.com/tracks/266891990/stream?secret_token=s-tj3IS&client_id=LBCcHmRB8XSStWL6wKH2HPACspQlXg2P",
      thumbUrl: "https://static1.squarespace.com/static/542b4e6fe4b0d082dad4801a/542f0deee4b09915be98e7d4/59da4ff49f7456baacd79051/1507479576977/Vents+V4.png?format=2500w", 
      title: 'Track 1',
      duration: Duration(seconds: 162),
      album: 'Audio',
    ));

    items.add(AudioPlayerItem(
      url: "https://api.soundcloud.com/tracks/258735531/stream?secret_token=s-tj3IS&client_id=LBCcHmRB8XSStWL6wKH2HPACspQlXg2P",
      thumbUrl: "https://static1.squarespace.com/static/542b4e6fe4b0d082dad4801a/542f0deee4b09915be98e7d4/542f0df2e4b04a3de8309e49/1412369919914/1+-+Desert+Pyramid.png?format=2500w", 
      title: 'Track 2',
      duration: Duration(seconds: 140),
      album: 'Audio',
    ));

    items.add(AudioPlayerItem(
      url: "https://api.soundcloud.com/tracks/9540779/stream?secret_token=s-tj3IS&client_id=LBCcHmRB8XSStWL6wKH2HPACspQlXg2P",
      thumbUrl: "https://static1.squarespace.com/static/542b4e6fe4b0d082dad4801a/542f0deee4b09915be98e7d4/59da4fabb1ffb6b10394c55f/1507479475845/Spokes+EP+-+Cover+Only.png?format=2500w", 
      title: 'Track 3',
      duration: Duration(seconds: 96),
      album: 'Audio',
    ));

    return items;
  }  

  @override
  void initState() {
    super.initState();
    
    audioPlayer = AudioPlayerService.audioPlayer();
    audioPlayer.addListener(
      AudioPlayerListener(
        onAudioStateChanged: (AudioPlayerState state) {
          setState(() {
            this.playerState = state;
          });
        },
        onIndexChangedExternally: (int index) {
          setState(() {
            this.itemIndex = index;
            this.currentItem = audioPlayer.playerItems[itemIndex];
          });
        },
        onPlayerPositionChanged: (Duration position) {
          setState(() {
            this.currentPosition = position;
          });
    }));
    
    audioPlayer.initPlayerQueue(this.getItems());
    itemIndex = 0;
    currentItem = audioPlayer.playerItems[itemIndex];
    
  }

  void play(){
    audioPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Player Service Example'),
        ),
        body: Center(
          child: Column(

            children: <Widget>[

              Expanded(child: Container()),

              IconButton(
                onPressed: play,
                icon: Icon(Icons.play_arrow, color: Colors.black)
              ),

              Expanded(child: Container()),

              Text(
                this.currentItem?.title ?? "Not set",
                style: TextStyle(color: Colors.black)
              ),

              Expanded(child: Container()),

              Text(
                Duration(seconds: this.currentPosition?.inSeconds ?? 0).toString() + " / " + Duration(seconds: this.currentItem?.duration?.inSeconds ?? 0).toString(),
                style: TextStyle(color: Colors.black)
              ),

              Expanded(child: Container()),

            ],

          ),
        ),
      ),
    );
  }
}
