defmodule Test.Fixtures.Dart.WidgetState do
  @moduledoc false
  use Test.LanguageFixture, language: "dart widget_state"

  @code ~S'''
  abstract class Widget {
  String get key;

  Element createElement();
  }

  abstract class StatefulWidget extends Widget {
  State createState();
  }

  abstract class State<T extends StatefulWidget> {
  T widget;

  State(this.widget);

  void setState(void Function() fn) {
    fn();
    markNeedsBuild();
  }

  void markNeedsBuild() {}

  Widget build();

  void initState() {}

  void dispose() {}
  }

  class Element {
  Widget widget;
  State? state;

  Element(this.widget);

  void mount() {
    if (widget is StatefulWidget) {
      state = (widget as StatefulWidget).createState();
      state!.initState();
    }
  }

  void unmount() {
    state?.dispose();
  }
  }

  abstract class BuildContext {
  Widget get widget;

  Element get element;
  }

  enum WidgetLifecycle {
  created,
  mounted,
  active,
  inactive,
  disposed
  }

  class RenderObject {
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;
  bool needsLayout = true;
  bool needsPaint = true;
  RenderObject? parent;
  List<RenderObject> children = [];

  void layout() {
    needsLayout = false;
  }

  void paint() {
    needsPaint = false;
  }

  void addChild(RenderObject child) {
    children.add(child);
    child.parent = this;
  }
  }
  '''
end
