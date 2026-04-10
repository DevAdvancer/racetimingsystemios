import 'package:barcode_widget/barcode_widget.dart' as barcode_package;
import 'package:flutter/material.dart';

class RunnerBarcodePreview extends StatelessWidget {
  const RunnerBarcodePreview({
    super.key,
    required this.data,
    this.runnerName,
    this.height = 88,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.showValue = true,
  });

  final String data;
  final String? runnerName;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final trimmedRunnerName = runnerName?.trim();
    final visibleLabel = trimmedRunnerName != null && trimmedRunnerName.isNotEmpty
        ? trimmedRunnerName
        : data;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              barcode_package.BarcodeWidget(
                data: data,
                barcode: barcode_package.Barcode.code128(),
                color: Colors.black,
                backgroundColor: Colors.white,
                drawText: false,
                height: height,
                width: width,
                errorBuilder: (context, error) => Text(
                  'Barcode preview unavailable',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ),
              if (showValue) ...[
                const SizedBox(height: 10),
                Text(
                  visibleLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
