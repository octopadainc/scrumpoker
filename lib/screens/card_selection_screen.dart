import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:html' as html;

import 'name_entry_screen.dart';

class CardSelectionScreen extends StatefulWidget {
  final String userName;

  const CardSelectionScreen({super.key, required this.userName});

  @override
  State<CardSelectionScreen> createState() => _CardSelectionScreenState();
}

class _CardSelectionScreenState extends State<CardSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String roomId = 'default';
  late String userId;
  String? selectedCard;

  final List<String> fibonacciCards = [
    '0', '1', '2', '3', '5', '8', '13', '21', '?', '☕'
  ];

  @override
  void initState() {
    super.initState();
    userId = _getOrCreateUserId();
    _addUser();
  }

  String _getOrCreateUserId() {
    const key = 'scrum_poker_user_id';
    final storage = html.window.sessionStorage;
    if (storage.containsKey(key)) {
      return storage[key]!;
    } else {
      final id = const Uuid().v4();
      storage[key] = id;
      return id;
    }
  }

  Future<void> _addUser() async {
    final playerRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(userId);

    await playerRef.set({
      'name': widget.userName,
      'card': '',
      'isRevealed': false,
      'selectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _selectCard(String card) async {
    setState(() {
      selectedCard = card;
    });

    final playerRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(userId);

    await playerRef.update({
      'card': card,
      'selectedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You selected: $card')),
    );
  }

  Future<void> _revealAllCards() async {
    final playersRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('players');

    final snapshot = await playersRef.get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({'isRevealed': true});
    }
  }

  Future<void> _resetGame() async {
    final playersRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('players');

    final snapshot = await playersRef.get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({
        'card': '',
        'isRevealed': false,
        'selectedAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      selectedCard = null;
    });
  }

  Future<void> _endGame() async {
    final playersRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('players');

    final snapshot = await playersRef.get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NameEntryScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${widget.userName}'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'Pick a card:',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: fibonacciCards.map((card) {
                        final isSelected = selectedCard == card;
                        return GestureDetector(
                          onTap: () => _selectCard(card),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.indigo : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(
                              card,
                              style: TextStyle(
                                fontSize: 22,
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const Text(
                      'Players:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('rooms')
                            .doc(roomId)
                            .collection('players')
                            .orderBy('selectedAt')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final players = snapshot.data!.docs;

                          return ListView.builder(
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final player = players[index].data() as Map<String, dynamic>;
                              final name = player['name'] ?? 'Unknown';
                              final card = player['card'] ?? '';
                              final isRevealed = player['isRevealed'] == true;

                              return ListTile(
                                title: Text(name),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isRevealed && card.isNotEmpty)
                                      Text(
                                        card,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      )
                                    else if (!isRevealed && card.isNotEmpty)
                                      const Icon(Icons.check_circle, color: Colors.green)
                                    else
                                      const Icon(Icons.hourglass_empty, color: Colors.grey),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _revealAllCards,
                          icon: const Icon(Icons.visibility),
                          label: const Text('Reveal All Cards'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _resetGame,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset Game'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _endGame,
                          icon: const Icon(Icons.stop_circle),
                          label: const Text('End Game'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
