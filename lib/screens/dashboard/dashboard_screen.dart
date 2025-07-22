import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pacta/services/auth_service.dart';
import 'package:pacta/screens/debt/add_debt_screen.dart';
import 'package:pacta/screens/debt/saved_contacts_screen.dart';
import '../debt/amount_input_screen.dart';
import '../auth/giris_ekrani.dart';
import 'package:pacta/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // Animasyon için controller
  late AnimationController _controller;
  late Animation<double> _fadeInAnim;
  int _selectedTab = 0;
  bool _hasNotification = true; // örnek
  bool _darkModeBeta = false;
  int _bakiyePage = 0;
  final PageController _bakiyeController = PageController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeInAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _bakiyeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF181A20) : const Color(0xFFF9FAFB);
    final Color card = isDark ? const Color(0xFF23262F) : Colors.white;
    final Color textMain = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    const Color green = Color(0xFF4ADE80);
    const Color red = Color(0xFFF87171);
    const Color yellow = Color(0xFFFACC15);
    const Color blue = Color(0xFF60A5FA);
    const Color purple = Color(0xFFC4B5FD);
    const Color navGlow = Color(0xFF86EFAC);
    final String userName = "Ahmet";
    final double toplamBorc = 120; // örnek
    final String borcDurum = toplamBorc >= 0
        ? "+${toplamBorc.toStringAsFixed(0)}₺"
        : "${toplamBorc.toStringAsFixed(0)}₺";
    final Color borcColor = toplamBorc > 0
        ? green
        : (toplamBorc < 0 ? red : textSec);
    final String today = DateFormat(
      'd MMMM EEEE',
      'tr_TR',
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst bilgi
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "👋 Merhaba, $userName!",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            today,
                            style: TextStyle(fontSize: 13, color: textSec),
                          ),
                        ],
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              color: textMain,
                              size: 28,
                            ),
                            onPressed: () {},
                            tooltip: 'Pacta Bildirimleri',
                          ),
                          if (_hasNotification)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: card, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Genel borç durumu kartı (Artık swipeable 3 kart)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: FadeTransition(
                    opacity: _fadeInAnim,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 160,
                          child: PageView(
                            controller: _bakiyeController,
                            onPageChanged: (i) =>
                                setState(() => _bakiyePage = i),
                            children: [
                              _BakiyeCard(
                                title: "Onaylanmış Pacta Bakiyem",
                                amount: "+120₺",
                                color: green,
                                subtitle: "Çift taraflı onaylanmış işlemler",
                              ),
                              _BakiyeCard(
                                title: "Pacta Bakiyem",
                                amount: "+80₺",
                                color: blue,
                                subtitle: "Kendi notların ve takiplerin",
                              ),
                              _BakiyeCard(
                                title: "Pacta Ortak",
                                amount: "+200₺",
                                color: purple,
                                subtitle: "Tüm işlemlerin toplamı",
                              ),
                            ],
                          ),
                        ),
                        // Sol ok
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: _bakiyePage == 0
                                  ? Colors.grey[300]
                                  : textSec,
                              size: 22,
                            ),
                            onPressed: _bakiyePage == 0
                                ? null
                                : () {
                                    _bakiyeController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  },
                          ),
                        ),
                        // Sağ ok
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: _bakiyePage == 2
                                  ? Colors.grey[300]
                                  : textSec,
                              size: 22,
                            ),
                            onPressed: _bakiyePage == 2
                                ? null
                                : () {
                                    _bakiyeController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  },
                          ),
                        ),
                        // Altında dot göstergesi
                        Positioned(
                          bottom: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              3,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: _bakiyePage == i ? 18 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _bakiyePage == i
                                      ? green
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Hızlı erişim butonları
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _AnimatedActionButton(
                        icon: Icons.send_rounded,
                        label: "Pacta Ver",
                        color: red,
                        onTap: () async {
                          final selectedEmail = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SavedContactsScreen(),
                            ),
                          );
                          if (selectedEmail != null &&
                              selectedEmail is String) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AmountInputScreen(
                                  selectedPersonEmail: selectedEmail,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _AnimatedActionButton(
                        icon: Icons.download_rounded,
                        label: "Pacta Al",
                        color: green,
                        onTap: () async {
                          final selectedEmail = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SavedContactsScreen(
                                title: 'Kimden Aldınız?',
                              ),
                            ),
                          );
                          if (selectedEmail != null &&
                              selectedEmail is String) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AmountInputScreen(
                                  selectedPersonEmail: selectedEmail,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _AnimatedActionButton(
                        icon: Icons.note_add_rounded,
                        label: "Not Ekle",
                        color: yellow,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddDebtScreen(),
                            ),
                          );
                        },
                      ),
                      _AnimatedActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: "Pacta Kapat",
                        color: blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddDebtScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Onaylı Hareketler ve Kendi Takiplerin başlıkları
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Onaylı Hareketler",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textMain,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          "Tümünü Gör",
                          style: TextStyle(color: textMain),
                        ),
                      ),
                    ],
                  ),
                ),
                // (Buraya onaylı hareketler listesi gelecek)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    "Kendi Takiplerin",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textMain,
                    ),
                  ),
                ),
                // (Buraya kendi takiplerin listesi gelecek)
                // Boş geçmiş durumu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 80,
                              color: Colors.black12,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              "Henüz Pacta oluşturmadın.",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Pactaların burada listelenecek.",
                              style: TextStyle(fontSize: 14, color: textSec),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed:
                                  null, // TODO: Yeni Pacta Oluştur fonksiyonu
                              icon: Icon(Icons.add, color: green),
                              label: Text(
                                "Yeni Pacta Oluştur",
                                style: TextStyle(color: green),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: green),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF23262F)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sağ altta dark mode butonu (beta)
          Positioned(
            right: 20,
            bottom: 32,
            child: Opacity(
              opacity: 0.7,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: "darkModeBtn",
                    backgroundColor: purple,
                    onPressed: () {
                      setState(() {
                        _darkModeBeta = !_darkModeBeta;
                        final brightness = _darkModeBeta
                            ? Brightness.dark
                            : Brightness.light;
                        // ignore: deprecated_member_use
                        WidgetsBinding.instance.window.platformBrightness ==
                            brightness;
                      });
                    },
                    child: const Icon(
                      Icons.nightlight_round,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Beta",
                      style: TextStyle(fontSize: 11, color: purple),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ModernBottomBar(
        selectedTab: _selectedTab,
        onTabChanged: (i) {
          setState(() => _selectedTab = i);
          if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }
        },
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AnimatedActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails d) => _controller.forward();
  void _onTapUp(TapUpDetails d) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color buttonBg = isDark ? const Color(0xFF23262F) : Colors.white;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: buttonBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(isDark ? 0.10 : 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark
                    ? Border.all(
                        color: widget.color.withOpacity(0.18),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Icon(widget.icon, color: widget.color, size: 28),
            ),
            const SizedBox(height: 7),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernBottomBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  const _ModernBottomBar({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color navGlow = Color(0xFF86EFAC);
    final Color barBg = isDark ? const Color(0xFF181A20) : Colors.white;
    final Color textSec = isDark ? Colors.white70 : const Color(0xFF6B7280);
    return Container(
      decoration: BoxDecoration(
        color: barBg,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : const Color(0x11000000),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < 4; i++)
            _ModernNavItem(
              icon: [
                Icons.home_rounded,
                Icons.people_alt_rounded,
                Icons.bar_chart_rounded,
                Icons.settings_rounded,
              ][i],
              label: ["Ana Sayfa", "Kişiler", "Analiz", "Ayarlar"][i],
              selected: selectedTab == i,
              onTap: () => onTabChanged(i),
            ),
        ],
      ),
    );
  }
}

class _ModernNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModernNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color navGlow = Color(0xFF86EFAC);
    const Color textMain = Color(0xFF111827);
    const Color textSec = Color(0xFF6B7280);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: navGlow.withOpacity(0.18),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: navGlow.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                Icon(icon, color: selected ? navGlow : textSec, size: 26),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? navGlow : textSec,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (selected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: navGlow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BakiyeCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final String subtitle;
  const _BakiyeCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF23262F) : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? null
            : LinearGradient(
                colors: [color.withOpacity(0.13), color.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isDark ? cardBg : null,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.08 : 0.13),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
