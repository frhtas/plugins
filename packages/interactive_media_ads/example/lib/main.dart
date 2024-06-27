// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:video_player/video_player.dart';

/// Entry point for integration tests that require espresso.
@pragma('vm:entry-point')
void integrationTestMain() {
  enableFlutterDriverExtension();
  main();
}

// IMA sample tag for a single skippable inline video ad. See more IMA sample
// tags at https://developers.google.com/interactive-media-ads/docs/sdks/html5/client-side/tags
const String _adTagUrl =
    'https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator=';

void main() {
  runApp(
    MaterialApp(
      // TODO(bparrishMines): Remove this check once the iOS implementation
      // is added.
      home: defaultTargetPlatform == TargetPlatform.android
          ? const AdExampleWidget()
          : Container(),
    ),
  );
}

/// Example widget displaying an Ad during a video.
class AdExampleWidget extends StatefulWidget {
  /// Constructs an [AdExampleWidget].
  const AdExampleWidget({super.key});

  @override
  State<AdExampleWidget> createState() => _AdExampleWidgetState();
}

class _AdExampleWidgetState extends State<AdExampleWidget> {
  late final AdsLoader _adsLoader;
  AdsManager? _adsManager;
  bool _shouldShowContentVideo = true;

  late final VideoPlayerController _contentVideoController;

  late final AdDisplayContainer _adDisplayContainer = AdDisplayContainer(
    onContainerAdded: (AdDisplayContainer container) {
      _requestAds(container);
    },
  );

  @override
  void initState() {
    super.initState();
    _contentVideoController = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://storage.googleapis.com/gvabox/media/samples/stock.mp4',
      ),
    )
      ..addListener(() {
        if (_contentVideoController.value.isCompleted) {
          _adsLoader.contentComplete();
          setState(() {});
        }
      })
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  Future<void> _resumeContent() {
    setState(() {
      _shouldShowContentVideo = true;
    });
    return _contentVideoController.play();
  }

  Future<void> _pauseContent() {
    setState(() {
      _shouldShowContentVideo = false;
    });
    return _contentVideoController.pause();
  }

  Future<void> _requestAds(AdDisplayContainer container) {
    _adsLoader = AdsLoader(
      container: container,
      onAdsLoaded: (OnAdsLoadedData data) {
        final AdsManager manager = data.manager;
        _adsManager = data.manager;

        manager.setAdsManagerDelegate(AdsManagerDelegate(
          onAdEvent: (AdEvent event) {
            debugPrint('OnAdEvent: ${event.type}');
            switch (event.type) {
              case AdEventType.loaded:
                manager.start();
              case AdEventType.contentPauseRequested:
                _pauseContent();
              case AdEventType.contentResumeRequested:
                _resumeContent();
              case AdEventType.allAdsCompleted:
                manager.destroy();
                _adsManager = null;
              case AdEventType.clicked:
              case AdEventType.complete:
            }
          },
          onAdErrorEvent: (AdErrorEvent event) {
            debugPrint('AdErrorEvent: ${event.error.message}');
            _resumeContent();
          },
        ));

        manager.init();
      },
      onAdsLoadError: (AdsLoadErrorData data) {
        debugPrint('OnAdsLoadError: ${data.error.message}');
        _resumeContent();
      },
    );

    return _adsLoader.requestAds(AdsRequest(adTagUrl: _adTagUrl));
  }

  @override
  void dispose() {
    super.dispose();
    _contentVideoController.dispose();
    _adsManager?.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: !_contentVideoController.value.isInitialized
              ? Container()
              : AspectRatio(
                  aspectRatio: _contentVideoController.value.aspectRatio,
                  child: Stack(
                    children: <Widget>[
                      // The display container must be on screen before any Ads can be
                      // loaded and can't be removed between ads. This handles clicks for
                      // ads.
                      _adDisplayContainer,
                      if (_shouldShowContentVideo)
                        VideoPlayer(_contentVideoController)
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton:
          _contentVideoController.value.isInitialized && _shouldShowContentVideo
              ? FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _contentVideoController.value.isPlaying
                          ? _contentVideoController.pause()
                          : _contentVideoController.play();
                    });
                  },
                  child: Icon(
                    _contentVideoController.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                )
              : null,
    );
  }
}
