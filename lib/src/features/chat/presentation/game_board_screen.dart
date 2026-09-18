import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class GameBoardScreen extends StatefulWidget {
  final String gameId;
  final String chatId;

  const GameBoardScreen({
    super.key,
    required this.gameId,
    required this.chatId,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final String currentUid = AppAuth.instance.currentUser?.uid ?? '';
  bool _exiting = false;
  String _prevStatus = 'waiting';
  bool _hasNotifiedStart = false;
  bool _callActive = false;

  Future<void> _makeMove(int index, List<dynamic> currentBoard, String currentTurn, String playerX, String playerO, String status) async {
    if (status != 'playing') return; // Cannot move unless the game has started
    if (currentTurn != currentUid) return; // Not your turn
    if (currentBoard[index] != '') return; // Slot already taken

    final symbol = (currentUid == playerX) ? 'X' : 'O';
    final nextTurn = (currentUid == playerX) ? playerO : playerX;

    final newBoard = List<dynamic>.from(currentBoard);
    newBoard[index] = symbol;

    HapticFeedback.lightImpact();

    String? winner;
    String nextStatus = 'playing';

    if (_checkWin(newBoard, symbol)) {
      winner = currentUid;
      nextStatus = 'finished';
    } else if (!newBoard.contains('')) {
      winner = 'draw';
      nextStatus = 'finished';
    }

    try {
      await AppDatabase.instance.table('games').doc(widget.gameId).update({
        'board': newBoard,
        'turn': nextTurn,
        'status': nextStatus,
        'winner': winner,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to make move: $e')),
        );
      }
    }
  }

  bool _checkWin(List<dynamic> board, String symbol) {
    const patterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
      [0, 4, 8], [2, 4, 6],             // Diagonals
    ];
    for (final p in patterns) {
      if (board[p[0]] == symbol && board[p[1]] == symbol && board[p[2]] == symbol) {
        return true;
      }
    }
    return false;
  }

  Future<void> _startGameCall({bool video = false}) async {
    // Create a call ID for the game session
    final callId = 'game_${widget.gameId}';
    
    // Get opponent name for call
    final doc = await AppDatabase.instance.table('games').doc(widget.gameId).get();
    final data = doc.data();
    String opponentName = 'Game Partner';
    if (data != null) {
      final playerX = data['playerX'] as String? ?? '';
      final playerO = data['playerO'] as String? ?? '';
      final playerXName = data['playerXName'] as String? ?? 'Player X';
      final playerOName = data['playerOName'] as String? ?? 'Player O';
      
      if (currentUid == playerX) {
        opponentName = playerOName;
      } else {
        opponentName = playerXName;
      }
    }
    
    // Navigate to call room
    if (mounted) {
      final encodedName = Uri.encodeComponent(opponentName);
      context.push('/call-room/$callId?caller=true&video=$video&name=$encodedName&photoUrl=');
      setState(() => _callActive = true);
    }
  }

  Future<void> _abortGame() async {
    if (_exiting) return;
    _exiting = true;
    try {
      final doc = await AppDatabase.instance.table('games').doc(widget.gameId).get();
      if (doc.exists && doc.data()?['status'] == 'playing') {
        await AppDatabase.instance.table('games').doc(widget.gameId).update({
          'status': 'aborted',
        });
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _abortGame();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F11),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _abortGame,
          ),
          title: const Text(
            'Tic-Tac-Toe Arena',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance.table('games').doc(widget.gameId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            }

            final data = snapshot.data?.data();
            if (data == null) {
              return const Center(child: Text('Game not found', style: TextStyle(color: Colors.white70)));
            }

            final board = data['board'] as List<dynamic>? ?? List.filled(9, '');
            final status = data['status'] as String? ?? 'waiting';
            final turn = data['turn'] as String? ?? '';
            final playerX = data['playerX'] as String? ?? '';
            final playerO = data['playerO'] as String? ?? '';
            final playerXName = data['playerXName'] as String? ?? 'Player X';
            final playerOName = data['playerOName'] as String? ?? 'Player O';
            final winner = data['winner'] as String?;

            final isPlayerX = currentUid == playerX;
            final mySymbol = isPlayerX ? 'X' : 'O';
            final isMyTurn = turn == currentUid && status == 'playing';

            // Notification check - show game start notification
            if (status == 'playing' && !_hasNotifiedStart) {
              _hasNotifiedStart = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Game accepted! Let the match begin!', style: TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              });
            }
            _prevStatus = status;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Call buttons when game is playing
                    if (status == 'playing' && !_callActive)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.videocam, color: Colors.greenAccent),
                              onPressed: () => _startGameCall(video: true),
                              tooltip: 'Start Video Call',
                              iconSize: 28,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.blueAccent),
                              onPressed: () => _startGameCall(video: false),
                              tooltip: 'Start Voice Call',
                              iconSize: 28,
                            ),
                          ],
                        ),
                      ),
                    // Players Indicator Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPlayerColumn(
                            playerXName,
                            'X',
                            turn == playerX && status == 'playing',
                            Colors.blueAccent,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('VS', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          _buildPlayerColumn(
                            status == 'waiting' ? 'Waiting...' : playerOName,
                            'O',
                            turn == playerO && status == 'playing',
                            Colors.pinkAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (status == 'waiting') ...[
                      // Waiting Screen without Layout
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Colors.purpleAccent),
                              const SizedBox(height: 24),
                              Text(
                                isPlayerX ? "Waiting for opponent to accept..." : "Joining game...",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "The game board will appear once they join.",
                                style: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      if (status == 'playing')
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isMyTurn ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isMyTurn ? Colors.green.withOpacity(0.3) : Colors.transparent),
                          ),
                          child: Text(
                            isMyTurn ? "Your Turn ($mySymbol)" : "Opponent's Turn...",
                            style: TextStyle(
                              color: isMyTurn ? Colors.greenAccent : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else if (status == 'finished')
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: winner == currentUid
                                ? Colors.green.withOpacity(0.15)
                                : (winner == 'draw' ? Colors.white10 : Colors.red.withOpacity(0.15)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            winner == currentUid
                                ? '🎉 Victory is Yours!'
                                : (winner == 'draw' ? '🤝 It\'s a Draw!' : '💀 Defeat...'),
                            style: TextStyle(
                              color: winner == currentUid
                                  ? Colors.greenAccent
                                  : (winner == 'draw' ? Colors.white : Colors.redAccent),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        )
                      else if (status == 'aborted')
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Game aborted by opponent.',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // 3x3 Tic Tac Toe Grid
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.01),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: 9,
                            itemBuilder: (context, idx) {
                              final cell = board[idx] as String;
                              final isCellX = cell == 'X';
                              final cellColor = isCellX ? Colors.blueAccent : Colors.pinkAccent;

                              return GestureDetector(
                                onTap: () => _makeMove(idx, board, turn, playerX, playerO, status),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cell.isNotEmpty 
                                          ? cellColor.withOpacity(0.3) 
                                          : Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                  child: Center(
                                    child: AnimatedScale(
                                      scale: cell.isNotEmpty ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.bounceOut,
                                      child: Text(
                                        cell,
                                        style: TextStyle(
                                          color: cellColor,
                                          fontSize: 40,
                                          fontWeight: FontWeight.w900,
                                          shadows: [
                                            Shadow(
                                              color: cellColor.withOpacity(0.4),
                                              blurRadius: 10,
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (status == 'finished' || status == 'aborted')
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Return to Chat', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerColumn(String name, String symbol, bool isTurn, Color color) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isTurn ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTurn ? color : Colors.transparent,
            ),
          ),
          child: Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
