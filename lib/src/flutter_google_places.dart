import 'dart:async';
import 'dart:io';

import 'package:algolia_places/places.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:rxdart/rxdart.dart';

class APlacesAutocompleteWidget extends StatefulWidget {
  final String apiKey;
  final String hint;
//  final Location location;
  final num offset;
  final num radius;
  final String language;
  final int hitsPerPage;
  final String sessionToken;
  final List<String> types;
  final bool strictbounds;
  final Mode mode;
  final Widget logo;
  final ValueChanged<PlacesAutocompleteResponse> onError;

  /// optional - sets 'proxy' value in google_maps_webservice
  ///
  /// In case of using a proxy the baseUrl can be set.
  /// The apiKey is not required in case the proxy sets it.
  /// (Not storing the apiKey in the app is good practice)
  final String proxyBaseUrl;

  /// optional - set 'client' value in google_maps_webservice
  ///
  /// In case of using a proxy url that requires authentication
  /// or custom configuration
  final BaseClient httpClient;

  APlacesAutocompleteWidget({
    @required this.apiKey,
    this.mode = Mode.fullscreen,
    this.hint = "Search",
    this.language,
    this.hitsPerPage,
    this.offset,
//    this.location,
    this.radius,
    this.sessionToken,
    this.types,
    this.strictbounds,
    this.logo,
    this.onError,
    Key key,
    this.proxyBaseUrl,
    this.httpClient,
  }) : super(key: key);

  @override
  State<APlacesAutocompleteWidget> createState() {
    if (mode == Mode.fullscreen) {
      return _PlacesAutocompleteScaffoldState();
    }
    return _PlacesAutocompleteOverlayState();
  }

  static PlacesAutocompleteState of(BuildContext context) =>
      context.ancestorStateOfType(const TypeMatcher<PlacesAutocompleteState>());
}

class _PlacesAutocompleteScaffoldState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(title: AppBarPlacesAutoCompleteTextField());
    final body = PlacesAutocompleteResult(
      onTap: Navigator.of(context).pop,
      logo: widget.logo,
    );
    return Scaffold(appBar: appBar, body: body);
  }
}

class _PlacesAutocompleteOverlayState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Column(children: <Widget>[
      Material(
          color: theme.dialogBackgroundColor,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(2.0), topRight: Radius.circular(2.0)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                color: theme.brightness == Brightness.light
                    ? Colors.black45
                    : null,
                icon: _iconBack,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              Expanded(
                  child: Padding(
                child: _textField(context),
                padding: const EdgeInsets.only(right: 8.0),
              )),
            ],
          )),
      Divider(
          //height: 1.0,
          )
    ]);

    Widget body;

    if (_searching) {
      body = Stack(
        children: <Widget>[_Loader()],
        alignment: FractionalOffset.bottomCenter,
      );
    } else if (_queryTextController.text.isEmpty ||
        _response == null ||
        _response.hits.isEmpty) {
      body = Material(
        color: theme.dialogBackgroundColor,
        child: widget.logo ?? PoweredByGoogleImage(),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(2.0),
            bottomRight: Radius.circular(2.0)),
      );
    } else {
      body = SingleChildScrollView(
        child: Material(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(2.0),
            bottomRight: Radius.circular(2.0),
          ),
          color: theme.dialogBackgroundColor,
          child: ListBody(
            children: _response.hits
                .map(
                  (hit) => PredictionTile(
                        hit: hit,
                        onTap: Navigator.of(context).pop,
                      ),
                )
                .toList(),
          ),
        ),
      );
    }

    final container = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
        child: Stack(children: <Widget>[
          header,
          Padding(padding: EdgeInsets.only(top: 48.0), child: body),
        ]));

    if (Platform.isIOS) {
      return Padding(padding: EdgeInsets.only(top: 8.0), child: container);
    }
    return container;
  }

  Icon get _iconBack =>
      Platform.isIOS ? Icon(Icons.arrow_back_ios) : Icon(Icons.arrow_back);

  Widget _textField(BuildContext context) => TextField(
        controller: _queryTextController,
        autofocus: true,
        style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black87
                : null,
            fontSize: 16.0),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black45
                : null,
            fontSize: 16.0,
          ),
          border: InputBorder.none,
        ),
      );
}

class _Loader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: BoxConstraints(maxHeight: 2.0),
        child: LinearProgressIndicator());
  }
}

class PlacesAutocompleteResult extends StatefulWidget {
  final ValueChanged<Hit> onTap;
  final Widget logo;

  PlacesAutocompleteResult({this.onTap, this.logo});

  @override
  _PlacesAutocompleteResult createState() => _PlacesAutocompleteResult();
}

class _PlacesAutocompleteResult extends State<PlacesAutocompleteResult> {
  @override
  Widget build(BuildContext context) {
    final state = APlacesAutocompleteWidget.of(context);
    assert(state != null);

    if (state._queryTextController.text.isEmpty ||
        state._response == null ||
        state._response.hits.isEmpty) {
      final children = <Widget>[];
      if (state._searching) {
        children.add(_Loader());
      }
      children.add(widget.logo ?? PoweredByGoogleImage());
      return Stack(children: children);
    }
    return PredictionsListView(
      hits: state._response.hits,
      onTap: widget.onTap,
    );
  }
}

class AppBarPlacesAutoCompleteTextField extends StatefulWidget {
  @override
  _AppBarPlacesAutoCompleteTextFieldState createState() =>
      _AppBarPlacesAutoCompleteTextFieldState();
}

class _AppBarPlacesAutoCompleteTextFieldState
    extends State<AppBarPlacesAutoCompleteTextField> {
  @override
  Widget build(BuildContext context) {
    final state = APlacesAutocompleteWidget.of(context);
    assert(state != null);

    return Container(
        alignment: Alignment.topLeft,
        margin: EdgeInsets.only(top: 4.0),
        child: TextField(
          controller: state._queryTextController,
          autofocus: true,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black.withOpacity(0.9)
                : Colors.white.withOpacity(0.9),
            fontSize: 16.0,
          ),
          decoration: InputDecoration(
            hintText: state.widget.hint,
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white30
                : Colors.black38,
            hintStyle: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black38
                  : Colors.white30,
              fontSize: 16.0,
            ),
            border: InputBorder.none,
          ),
        ));
  }
}

class PoweredByGoogleImage extends StatelessWidget {
  final _poweredByGoogleWhite =
      "packages/flutter_google_places/assets/search-by-algolia-light-background.png";
  final _poweredByGoogleBlack =
      "packages/flutter_google_places/assets/search-by-algolia-dark-background.png";

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Padding(
          padding: EdgeInsets.all(16.0),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.light
                ? _poweredByGoogleWhite
                : _poweredByGoogleBlack,
            scale: 2.5,
          ))
    ]);
  }
}

class PredictionsListView extends StatelessWidget {
  final List<Hit> hits;
  final ValueChanged<Hit> onTap;

  PredictionsListView({@required this.hits, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children:
          hits.map((Hit p) => PredictionTile(hit: p, onTap: onTap)).toList(),
    );
  }
}

class PredictionTile extends StatelessWidget {
  final Hit hit;
  final ValueChanged<Hit> onTap;

  PredictionTile({
    @required this.hit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.location_on),
      title: Text(
          '${hit.suggestion.name} ${hit.suggestion.administrative}, ${hit.suggestion.country}'),
      onTap: () {
        if (onTap != null) {
          onTap(hit);
        }
      },
    );
  }
}

enum Mode { overlay, fullscreen }

abstract class PlacesAutocompleteState
    extends State<APlacesAutocompleteWidget> {
  TextEditingController _queryTextController;
  PlacesAutocompleteResponse _response;
  AlgoliaPlaces _places;
  bool _searching;

  final _queryBehavior = BehaviorSubject<String>.seeded('');

  @override
  void initState() {
    super.initState();
    _queryTextController = TextEditingController(text: "");

    _places = AlgoliaPlaces(
      apiKey: widget.apiKey,
      httpClient: widget.httpClient,
    );
    _searching = false;

    _queryTextController.addListener(_onQueryChange);

    _queryBehavior.stream
        .debounceTime(const Duration(milliseconds: 300))
        .listen(doSearch);
  }

  Future<Null> doSearch(String value) async {
    if (mounted && value.isNotEmpty) {
      setState(() {
        _searching = true;
      });

      final res = await _places.autocomplete(
        value,
        language: widget.language,
        hitsPerPage: widget.hitsPerPage,
//        offset: widget.offset,
////        location: widget.location,
//        radius: widget.radius,
//        language: widget.language,
//        sessionToken: widget.sessionToken,
//        types: widget.types,
////        components: widget.components,
//        strictbounds: widget.strictbounds,
      );

      if (res.errorMessage?.isNotEmpty == true ||
          res.status == "REQUEST_DENIED") {
        onResponseError(res);
      } else {
        onResponse(res);
      }
    } else {
      onResponse(null);
    }
  }

  void _onQueryChange() {
    _queryBehavior.add(_queryTextController.text);
  }

  @override
  void dispose() {
    super.dispose();

    _places.dispose();
    _queryBehavior.close();
    _queryTextController.removeListener(_onQueryChange);
  }

  @mustCallSuper
  void onResponseError(PlacesAutocompleteResponse res) {
    if (!mounted) return;

    if (widget.onError != null) {
      widget.onError(res);
    }
    setState(() {
      _response = null;
      _searching = false;
    });
  }

  @mustCallSuper
  void onResponse(PlacesAutocompleteResponse res) {
    if (!mounted) return;

    setState(() {
      _response = res;
      _searching = false;
    });
  }
}

class PlacesAutocomplete {
  static Future<Hit> show(
      {@required BuildContext context,
      @required String apiKey,
      Mode mode = Mode.fullscreen,
      String hint = "Search",
      num offset,
//      Location location,
      num radius,
      String language,
      String sessionToken,
      List<String> types,
//      List<Component> components,
      bool strictbounds,
      Widget logo,
      ValueChanged<PlacesAutocompleteResponse> onError,
      String proxyBaseUrl,
      Client httpClient}) {
    final builder = (BuildContext ctx) => APlacesAutocompleteWidget(
        apiKey: apiKey,
        mode: mode,
        language: language,
        sessionToken: sessionToken,
//        components: components,
        types: types,
//        location: location,
        radius: radius,
        strictbounds: strictbounds,
        offset: offset,
        hint: hint,
        logo: logo,
        onError: onError,
        proxyBaseUrl: proxyBaseUrl,
        httpClient: httpClient);

    if (mode == Mode.overlay) {
      return showDialog(context: context, builder: builder);
    }
    return Navigator.push(context, MaterialPageRoute(builder: builder));
  }
}
