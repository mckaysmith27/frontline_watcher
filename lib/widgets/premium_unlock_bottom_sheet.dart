import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import '../config/app_config.dart';
import 'marketing_points.dart';
import '../utils/stripe_checkout_helpers.dart';

class PremiumUnlockBottomSheet extends StatefulWidget {
  const PremiumUnlockBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final brightness = Theme.of(context).brightness;
    final scrimAlpha = brightness == Brightness.dark ? 0.55 : 0.25;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: scrimAlpha),
      builder: (sheetContext) {
        return Stack(
          children: [
            // Tap anywhere outside the visible sheet to dismiss.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(sheetContext).maybePop(),
              child: const SizedBox.expand(),
            ),
            const PremiumUnlockBottomSheet(),
          ],
        );
      },
    );
  }

  @override
  State<PremiumUnlockBottomSheet> createState() => _PremiumUnlockBottomSheetState();
}

class _PremiumUnlockBottomSheetState extends State<PremiumUnlockBottomSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedTier;
  int _headlineIndex = 0;

  Map<String, Map<String, dynamic>> get _tiers => AppConfig.subscriptionTiers;

  final DraggableScrollableController _sheetController = DraggableScrollableController();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _promoController = TextEditingController();
  _PromoInfo? _promo;
  bool _promoCardRequired = true;
  bool _isProcessing = false;
  String? _inlineStatusMessage;
  bool _inlineStatusIsError = false;

  late final AnimationController _crownController;
  late final Animation<double> _crownWobble;
  Timer? _crownIntroTimer;
  Timer? _crownIntroTimer2;

  late final AnimationController _chooseController;
  late final Animation<double> _chooseBounce;
  Timer? _chooseFirstTimer;
  Timer? _choosePeriodicTimer;

  bool _showScrollCoach = true;
  Timer? _coachAutoHideTimer;
  late final AnimationController _coachController;
  late final Animation<double> _coachDy;

  double _applyPromoToBase(double baseUsd, _PromoInfo promo) {
    var finalUsd = baseUsd;
    if (promo.discountType == 'free') {
      finalUsd = 0.0;
    } else if (promo.discountType == 'percent' && promo.percentOff != null) {
      finalUsd = baseUsd * (1 - (promo.percentOff! / 100));
    } else if (promo.discountType == 'amount' && promo.amountOffUsd != null) {
      finalUsd = baseUsd - promo.amountOffUsd!;
    }
    if (finalUsd < 0) finalUsd = 0;
    return finalUsd;
  }

  bool _promoAppliesToTier(String tier) {
    final p = _promo;
    if (p == null) return false;
    if (p.tier == null) return true;
    return p.tier == tier.toLowerCase();
  }

  double _displayPriceForTier(String tier, double baseUsd) {
    final p = _promo;
    if (p == null) return baseUsd;
    if (!_promoAppliesToTier(tier)) return baseUsd;
    return _applyPromoToBase(baseUsd, p);
  }

  String _formatUsd(double v) => v.toStringAsFixed(2);

  Future<void> _showCheckoutErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkout failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPromo() async {
    final promo = _promoController.text.trim();
    if (promo.isEmpty) return;
    try {
      final callable = _functions.httpsCallable('validatePromoCode');
      // Validate without forcing a tier; promo may be global or tier-specific.
      final res = await callable.call({'code': promo});
      final data = Map<String, dynamic>.from(res.data as Map);
      final cardReq = data['isCardStillRequired'] == true;
      setState(() {
        _promo = _PromoInfo.fromMap(data);
        _promoCardRequired = cardReq;
        _inlineStatusMessage = 'Promo applied.';
        _inlineStatusIsError = false;
      });
    } catch (e) {
      setState(() {
        _promo = null;
        _inlineStatusMessage = 'Invalid promo code: $e';
        _inlineStatusIsError = true;
      });
      await _showCheckoutErrorDialog('Invalid promo code: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Default selection: Monthly.
    if (_tiers.containsKey('monthly')) {
      _selectedTier = 'monthly';
    } else if (_tiers.isNotEmpty) {
      _selectedTier = _tiers.keys.first;
    }

    _crownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _crownWobble = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.30), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.30, end: 0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.18), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _crownController, curve: Curves.easeOut));

    _chooseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _chooseBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 55),
    ]).animate(_chooseController);

    _coachController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _coachDy = Tween<double>(begin: 0, end: -48).animate(CurvedAnimation(parent: _coachController, curve: Curves.easeInOut));
    // Keep the coach overlay fully visible (no blinking/fading). We only hide it
    // when the user scrolls/drags, or after the timeout.

    _startHeadlineLoop();
    // Trigger the crown "ring" after the sheet is visible (post-frame),
    // otherwise the animation can play during the route transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _crownIntroTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _ringCrown();
        // A second quick "ring" makes the moment feel more exciting.
        _crownIntroTimer2 = Timer(const Duration(milliseconds: 850), () {
          if (!mounted) return;
          _ringCrown();
        });
      });
    });

    // Bounce "Choose your Premium Subscription" after 3s, then every 12s.
    _chooseFirstTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _bounceChooseLine();
      _choosePeriodicTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (!mounted) return;
        _bounceChooseLine();
      });
    });

    // Auto-hide coach overlay after a short time.
    _coachAutoHideTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _showScrollCoach = false);
    });

    _sheetController.addListener(() {
      if (!_showScrollCoach) return;
      // If the sheet has been pulled higher, hide the coach.
      if (_sheetController.size > 0.72) {
        if (mounted) setState(() => _showScrollCoach = false);
      }
    });
  }

  @override
  void dispose() {
    _chooseFirstTimer?.cancel();
    _choosePeriodicTimer?.cancel();
    _crownIntroTimer?.cancel();
    _crownIntroTimer2?.cancel();
    _coachAutoHideTimer?.cancel();
    _promoController.dispose();
    _coachController.dispose();
    _sheetController.dispose();
    _chooseController.dispose();
    _crownController.dispose();
    super.dispose();
  }

  void _ringCrown() {
    _crownController
      ..reset()
      ..forward();
  }

  void _bounceChooseLine() {
    _chooseController
      ..reset()
      ..forward();
  }

  void _startHeadlineLoop() {
    // Keep each headline visible long enough to read.
    Future<void>.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() => _headlineIndex = (_headlineIndex + 1) % 3);
      _startHeadlineLoop();
    });
  }

  Widget _premiumTitle(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    final baseBoldStyle =
        (style ?? const TextStyle(fontSize: 24)).copyWith(fontWeight: FontWeight.w800);
    final premiumStyle = baseBoldStyle.copyWith(fontWeight: FontWeight.w900);

    return Text.rich(
      TextSpan(
        style: baseBoldStyle,
        children: [
          const TextSpan(text: 'Unlock '),
          TextSpan(text: 'Premium', style: premiumStyle),
          // No space between Premium and crown; crown floats above the "m".
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: AnimatedBuilder(
              animation: _crownWobble,
              builder: (context, _) {
                // Base tilt slightly right, then wobble like a bell.
                final baseTilt = 0.22; // radians
                return Transform.translate(
                  offset: const Offset(-2, -12),
                  child: Transform.rotate(
                    angle: baseTilt + _crownWobble.value,
                    child: SvgPicture.asset(
                      'assets/icons/crown.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFFFD54F), // gold-ish
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const TextSpan(text: ' Features!'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _headline(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        );

    Widget child;
    if (_headlineIndex == 0) {
      child = Text(
        'Get alerts, get the job, get preferred, get booked for more jobs.',
        style: style,
        textAlign: TextAlign.center,
      );
    } else if (_headlineIndex == 1) {
      child = Text(
        '"I can actually accept the job before it disappears! 🥲" —Mr.H',
        style: style,
        textAlign: TextAlign.center,
      );
    } else {
      child = Text(
        '"It shouldn’t be a part time job just trying to get a job. Sub67 = Problem Solved!" —Mr.McCay',
        style: style,
        textAlign: TextAlign.center,
      );
    }

    // Keep this area a fixed height so the rest of the sheet doesn't jump
    // as sentences change length.
    return SizedBox(
      height: 86,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: SizedBox(
          key: ValueKey(_headlineIndex),
          width: double.infinity,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (_showScrollCoach && n.metrics.pixels > 4) {
                          setState(() => _showScrollCoach = false);
                        }
                        return false;
                      },
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        children: [
                          _premiumTitle(context),
                          const SizedBox(height: 12),

                          // Marketing headline carousel
                          _headline(context),
                          const SizedBox(height: 12),

                          // Feature bullets (with icons)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const MarketingPointRow(point: MarketingPointKey.fastAlerts),
                                  const MarketingPointRow(point: MarketingPointKey.priorityBooking),
                                  const MarketingPointRow(point: MarketingPointKey.keywordFiltering),
                                  const MarketingPointRow(point: MarketingPointKey.calendarSync),
                                  const MarketingPointRow(point: MarketingPointKey.bizCards),
                                  const MarketingPointRow(point: MarketingPointKey.qrCodeLink),
                                  const MarketingPointRow(point: MarketingPointKey.communityConnect),
                                  const MarketingPointRow(point: MarketingPointKey.educatorSupport),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _chooseBounce,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _chooseBounce.value),
                                child: child,
                              );
                            },
                            child: Text(
                              'Choose your Premium Subscription duration:',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Promo code (inline, no separate checkout page).
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Promo code',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _promoController,
                                          textInputAction: TextInputAction.done,
                                          decoration: const InputDecoration(
                                            hintText: 'Enter code',
                                            border: OutlineInputBorder(),
                                          ),
                                          onSubmitted: (_) => _applyPromo(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton(
                                        onPressed: _applyPromo,
                                        child: const Text('Apply'),
                                      ),
                                    ],
                                  ),
                                  if ((_inlineStatusMessage ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      _inlineStatusMessage!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: _inlineStatusIsError
                                                ? Theme.of(context).colorScheme.error
                                                : Colors.green[700],
                                          ),
                                    ),
                                  ],
                                  if (_promo != null && _promoCardRequired) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Card still required for renewal.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._tiers.entries.map((entry) {
                      final isSelected = _selectedTier == entry.key;
                      final pretty = entry.key
                          .split('-')
                          .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
                          .join(' ');
                      final title = entry.key == 'monthly' ? '$pretty (recommended)' : pretty;
                      final baseUsd = (entry.value['price'] as num).toDouble();
                      final displayUsd = _displayPriceForTier(entry.key, baseUsd);
                      final promoApplies = _promoAppliesToTier(entry.key);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => setState(() => _selectedTier = entry.key),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: entry.key,
                                  groupValue: _selectedTier,
                                  onChanged: (value) => setState(() => _selectedTier = value),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontSize: 16,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${entry.value['days']} days • ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          if (promoApplies && displayUsd != baseUsd) ...[
                                            Text(
                                              '\$${_formatUsd(baseUsd)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '\$${_formatUsd(displayUsd)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green[700],
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              '\$${_formatUsd(baseUsd)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: (_selectedTier != null && !_isProcessing) ? _checkout : null,
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: Text(_isProcessing ? 'Processing…' : 'Checkout'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_showScrollCoach)
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _coachController,
                            builder: (context, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.72),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(0, _coachDy.value),
                                      child: Transform.rotate(
                                        // Make it feel like a finger swipe up.
                                        angle: -0.22,
                                        child: const Icon(
                                          Icons.touch_app,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          'Swipe up',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'to select subscription',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Transform.translate(
                                      offset: Offset(0, _coachDy.value),
                                      child: const Icon(
                                        Icons.keyboard_arrow_up,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkout() async {
    final tier = _selectedTier;
    if (tier == null) return;
    final tierData = _tiers[tier];
    if (tierData == null) return;

    final days = (tierData['days'] as num).toInt();
    final basePriceUsd = (tierData['price'] as num).toDouble();
    final promoCode = _promoAppliesToTier(tier) ? _promo?.code : null;

    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _inlineStatusMessage = null;
      _inlineStatusIsError = false;
    });

    String? intentId;
    String mode = 'none'; // none|setup|payment

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      if (stripe.Stripe.publishableKey.trim().isEmpty) {
        throw Exception(
          'Stripe is not configured yet (missing publishable key). '
          'Set functions config stripe.publishable_key and redeploy functions.',
        );
      }

      final createCallable = _functions.httpsCallable('createStripePaymentSession');
      final sessionRes = await createCallable.call({
        'tier': tier,
        'basePriceUsd': basePriceUsd,
        if (promoCode != null) 'promoCode': promoCode,
      });
      final session = Map<String, dynamic>.from(sessionRes.data as Map);

      mode = (session['mode'] as String?) ?? 'none'; // none|setup|payment
      intentId = session['intentId'] as String?;
      final customerId = session['customerId'] as String?;
      final ephemeralKeySecret = session['ephemeralKeySecret'] as String?;
      final paymentIntentClientSecret = session['paymentIntentClientSecret'] as String?;
      final setupIntentClientSecret = session['setupIntentClientSecret'] as String?;

      if (mode == 'payment') {
        await stripe.Stripe.instance.initPaymentSheet(
          paymentSheetParameters: stripe.SetupPaymentSheetParameters(
            merchantDisplayName: AppConfig.stripeMerchantDisplayName,
            customerId: customerId,
            customerEphemeralKeySecret: ephemeralKeySecret,
            paymentIntentClientSecret: paymentIntentClientSecret,
            style: ThemeMode.system,
          ),
        );
        await stripe.Stripe.instance.presentPaymentSheet();
      } else if (mode == 'setup') {
        await stripe.Stripe.instance.initPaymentSheet(
          paymentSheetParameters: stripe.SetupPaymentSheetParameters(
            merchantDisplayName: AppConfig.stripeMerchantDisplayName,
            customerId: customerId,
            customerEphemeralKeySecret: ephemeralKeySecret,
            setupIntentClientSecret: setupIntentClientSecret,
            style: ThemeMode.system,
          ),
        );
        await stripe.Stripe.instance.presentPaymentSheet();
      }

      final confirmCallable = _functions.httpsCallable('confirmSubscriptionPurchase');
      await confirmCallable.call({
        'tier': tier,
        'days': days,
        'mode': mode,
        if (intentId != null) 'intentId': intentId,
        if (promoCode != null) 'promoCode': promoCode,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription active for $days days.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final isCanceled = StripeCheckoutHelpers.isUserCanceled(e);

      // Best-effort: if the PaymentSheet was dismissed/canceled, attempt to confirm anyway.
      // Some external flows (e.g., Link) may succeed but return a cancellation signal.
      if (isCanceled && mode != 'none' && intentId != null) {
        try {
          final confirmCallable = _functions.httpsCallable('confirmSubscriptionPurchase');
          await confirmCallable.call({
            'tier': tier,
            'days': days,
            'mode': mode,
            'intentId': intentId,
            if (promoCode != null) 'promoCode': promoCode,
          });

          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subscription active for $days days.'),
              backgroundColor: Colors.green,
            ),
          );
          return;
        } catch (_) {
          // fall through to canceled message
        }
      }

      final msg = isCanceled ? 'Payment canceled.' : 'Checkout failed: ${StripeCheckoutHelpers.format(e)}';
      setState(() {
        _inlineStatusMessage = msg;
        _inlineStatusIsError = !isCanceled;
      });
      if (!isCanceled) {
        await _showCheckoutErrorDialog(msg);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _PromoInfo {
  const _PromoInfo({
    required this.code,
    required this.discountType,
    required this.isCardStillRequired,
    this.tier,
    this.percentOff,
    this.amountOffUsd,
  });

  final String code;
  final String? tier; // null means global
  final String discountType; // free|percent|amount
  final double? percentOff;
  final double? amountOffUsd;
  final bool isCardStillRequired;

  factory _PromoInfo.fromMap(Map<String, dynamic> data) {
    return _PromoInfo(
      code: (data['code'] as String? ?? '').toUpperCase(),
      tier: (data['tier'] as String?)?.toLowerCase(),
      discountType: (data['discountType'] as String? ?? 'free').toLowerCase(),
      percentOff: (data['percentOff'] is num) ? (data['percentOff'] as num).toDouble() : null,
      amountOffUsd: (data['amountOffUsd'] is num) ? (data['amountOffUsd'] as num).toDouble() : null,
      isCardStillRequired: data['isCardStillRequired'] == true,
    );
  }
}

