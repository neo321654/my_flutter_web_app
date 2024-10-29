import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// [Widget] building the [MaterialApp].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock<IconData>(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (e) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[e.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(e, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dock of the reorderable [items].
class Dock<T extends Object> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T extends Object> extends State<Dock<T>> {
  /// List of [T] items being manipulated.
  late final List<T> _items = widget.items.toList();

  /// Global delta offset for dragging items.
  Offset globalDeltaOffset = Offset.infinite;

  /// Global offset for dragging items.
  Offset globalOffset = Offset.infinite;

  /// The item that is currently hidden during drag.
  T? _itemToHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _items.map((e) {
          return DockItem<T>(
            key: ValueKey(e),
            item: e,
            globalDeltaOffset: globalDeltaOffset,
            globalOffset: globalOffset,
            setGlobalOffset: setGlobalOffset,
            setGlobalDeltaOffset: setGlobalDeltaOffset,
            builder: widget.builder,
            onDrop: onDrop,
            isVisible: e != _itemToHide, // Determines visibility of the item.
          );
        }).toList(),
      ),
    );
  }

  /// Handles the drop action for reordering items in the dock.
  void onDrop(T itemToReplace, T item) {
    setState(() {
      int index = _items.indexOf(item);
      _items.remove(itemToReplace);
      _items.insert(index, itemToReplace);
    });
  }

  /// Sets the global delta offset during drag operations.
  void setGlobalDeltaOffset(Offset offset) {
    setState(() {
      globalDeltaOffset = offset;
    });
  }

  /// Sets the global offset during drag operations.
  void setGlobalOffset(Offset offset) {
    setState(() {
      globalOffset = offset;
    });
  }
}

/// A draggable item in the dock.
class DockItem<T extends Object> extends StatefulWidget {
  /// Creates a [DockItem].
  const DockItem({
    required this.item,
    required this.builder,
    required this.onDrop,
    required this.setGlobalDeltaOffset,
    required this.setGlobalOffset,
    required this.globalDeltaOffset,
    required this.globalOffset,
    this.isVisible = true,
    super.key,
  });

  /// The item to be displayed in the dock.
  final T item;

  /// Builder function to create the widget representation of the provided [item].
  final Widget Function(T) builder;

  /// Callback function invoked when an item is dropped.
  final Function(T itemToRemove, T item) onDrop;

  /// Callback to set the global delta offset during dragging.
  final Function(Offset offset) setGlobalDeltaOffset;

  /// Callback to set the global offset during dragging.
  final Function(Offset offset) setGlobalOffset;

  /// Current global delta offset during dragging.
  final Offset globalDeltaOffset;

  /// Current global offset during dragging.
  final Offset globalOffset;

  /// Visibility of the dock item. Defaults to true.
  final bool isVisible;

  @override
  State<DockItem<T>> createState() => _DockItemState<T>();
}

/// State for [DockItem], managing its behavior and appearance during drag operations.
class _DockItemState<T extends Object> extends State<DockItem<T>> {

  /// Indicates if the item is currently being dragged.
  bool isDragging = false;

  /// Tracks visibility of the dock item.
  late bool isVisible;

  /// Holds the widget created by the builder function.
  late Widget widgetFromBuilder;

  /// Offset for animation when dragging ends.
  Offset offsetToDelta = Offset.zero;

  /// Offset for the position when leaving a target area.
  Offset offsetToLeave = Offset.zero;

  /// Offset for the position when accepting a drop.
  Offset offsetToAccept = Offset.zero;

  @override
  void initState() {
    super.initState();
    isVisible = widget.isVisible; // Initialize visibility state.
    widgetFromBuilder = widget.builder(widget.item); // Create widget from builder function.
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: isVisible, // Control visibility based on state.
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Draggable<T>(
        data: widget.item, // Data passed during drag and drop operations.
        onDragStarted: () {
          isDragging = true; // Set dragging state to true when drag starts.
          isVisible = false; // Hide the item being dragged.
        },
        onDragEnd: (details) {
          isDragging = false; // Reset dragging state when drag ends.

          showOverlayAnimation(
              begin: details.offset, // Start position for overlay animation.
              end: widget.globalOffset, // End position for overlay animation.
              context: context);

          resetGlobalDelta(); // Reset delta offsets after drag ends.
        },
        onDragCompleted: () {
          isDragging = false; // Reset dragging state when drag completes.
          isVisible = true; // Show the item again after completion.
          resetGlobalDelta(); // Reset delta offsets after drag completes.
        },
        onDraggableCanceled: (velocity, offset) {
          isDragging = false; // Reset dragging state if drag is canceled.
          isVisible = true; // Show the item again if canceled.
          resetGlobalDelta(); // Reset delta offsets after cancellation.
        },
        dragAnchorStrategy: (Draggable<Object> draggable, BuildContext context, Offset position) {
          RenderBox renderObject = getRenderBoxObject(context)!; // Get render object for positioning.

          Offset? offSet = getParentOffset(renderObject); // Get parent offset.

          if (offSet != null) {
            Offset ofToGlobal = renderObject.localToGlobal(offSet) - offSet;
            widget.setGlobalDeltaOffset(offSet); // Update global delta offset.
            widget.setGlobalOffset(ofToGlobal); // Update global offset based on position.
          }

          return renderObject.globalToLocal(position); // Convert position to local coordinates.
        },
        childWhenDragging: Visibility(
          visible:isVisible,
          maintainSize:true,
          maintainAnimation:true,
          maintainState:true,
          child :widgetFromBuilder,
        ),
        feedback :widgetFromBuilder,
        child :DragTarget<T>(
          builder:(BuildContext context,candidateData,rejectedData){
            if (candidateData.isNotEmpty) {
              RenderBox renderBox = context.findRenderObject() as RenderBox; // Get render box for positioning.

              Offset offsetBias = getParentOffset(renderBox) ?? Offset.zero; // Calculate offset bias.

              Offset ofToGlobal =
                  renderBox.localToGlobal(offsetBias) - offsetBias; // Calculate global offset.

              offsetToAccept = ofToGlobal;

              WidgetsBinding.instance.addPostFrameCallback((d) {
                widget.setGlobalOffset(ofToGlobal);
              });

              offsetToLeave = offsetBias;

              offsetToDelta = widget.globalDeltaOffset - offsetBias;

              // Calculate horizontal or vertical shift
              offsetToDelta = Offset(
                renderBox.size.width * offsetToDelta.dx.sign,
                offsetToDelta.dy,
              );

              return AnimatedOffsetWidget(
                begin : Offset.zero,
                end :offsetToDelta,
                duration :const Duration(milliseconds :600),
                child :widgetFromBuilder ,
                builder :(context ,offset ,child){
                  return Transform.translate(
                    offset :offset ,
                    child :widgetFromBuilder ,
                  );
                },
              );
            }

            return widgetFromBuilder; // Return default widget if no candidates are present
          },
          onAcceptWithDetails:(data){
            widget.setGlobalOffset(offsetToAccept);
            widget.onDrop(data.data ,widget.item);
          },
          onLeave:(data){
            widget.setGlobalDeltaOffset(offsetToLeave);
            widget.onDrop(data!, widget.item);
          },
        ),
      ),
    );
  }

  /// Retrieves the parent offset of a given [RenderBox].
  Offset? getParentOffset(RenderBox? renderObject) {
    if (renderObject == null) return null;

    BoxParentData? pData = findBoxParentData(renderObject);

    if (pData != null) return pData.offset;

    return null;
  }

  /// Finds and returns the [BoxParentData] of a given [RenderBox].
  BoxParentData? findBoxParentData(RenderBox? renderBox) {
    if (renderBox == null) return null;

    RenderObject? parent = renderBox.parent;

    if (parent == null) return null;

    while (parent != null) {
      var parentData = parent.parentData;
      if (parentData is BoxParentData) {
        return parentData;
      }
      parent = parent.parent;
    }
    return null;
  }

  /// Retrieves the [RenderBox] object from a given [BuildContext].
  RenderBox? getRenderBoxObject(BuildContext context) {
    RenderObject? renderObject = context.findRenderObject();
    if (renderObject != null && renderObject is RenderBox) {
      return renderObject;
    }
    return null;
  }

  /// Resets the global delta offsets to zero and updates state accordingly.
  void resetGlobalDelta() {
    offsetToDelta = Offset.zero;
    widget.setGlobalDeltaOffset(Offset.infinite);
  }

  /// Shows overlay animation during drag and drop operation.
  void showOverlayAnimation({
    required Offset begin,
    required Offset end,
    required BuildContext context
  }) {
    OverlayEntry? overlayEntry;

    void removeOverlayEntry() {
      overlayEntry?.remove();
      overlayEntry?.dispose();
      overlayEntry = null;
    }

    overlayEntry = OverlayEntry(
      builder:(BuildContext context){
        return Stack(
          fit :StackFit.expand ,
          children :[
            Positioned(
              top:end.dy ,
              left:end.dx ,
              child :Container(
                height :64 ,
                width :64 ,
                color :const Color(0xffDFD9DF),
              ),
            ),
            AnimatedOffsetWidget(
              begin :begin ,
              end :end ,
              duration :const Duration(milliseconds :1000),
              onEnd :removeOverlayEntry ,
              child :widgetFromBuilder ,
              builder :(context ,offset ,child){
                return Positioned(
                  top :offset.dy ,
                  left :offset.dx ,
                  child :widgetFromBuilder ,
                );
              },
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(overlayEntry!); // Insert overlay entry into the overlay stack
  }
}

/// A widget that animates its position based on offsets during transitions.
class AnimatedOffsetWidget extends StatelessWidget {

  /// Builder function that receives both current animated value and its associated child. This allows you to customize how your animated value should be rendered.
  final ValueWidgetBuilder<Offset> builder;

  /// The starting position for animation transition.
  final Offset begin;

  /// The ending position for animation transition.
  final Offset end;

  /// Duration of the animation transition effect.
  final Duration duration;

  /// Child widget that will be animated during transition effects.
  final Widget child;

  /// Animation curve for transition effect. Defaults to [Curves.easeInOutExpo].
  final Curve curve;

  /// Callback function invoked when animation ends. Optional callback function.
  final void Function()? onEnd;

  const AnimatedOffsetWidget({
    super.key,
    required this.begin,
    required this.end,
    required this.duration,
    required this.child,
    required this.builder,
    this.curve = Curves.easeInOutExpo,
    this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      curve: curve,
      tween: Tween<Offset>(
        begin: begin,
        end: end,
      ),
      duration: duration,
      onEnd: onEnd,
      builder: builder,
      child: child,
    );
  }
}
