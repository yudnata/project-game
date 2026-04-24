# project-game (Godot Starter)

Starter project ini disiapkan untuk membuat game 2D top-down ala farming/life sim seperti Stardew Valley.

## Yang sudah disetup

- Struktur folder rapi untuk scene dan script
- Scene utama yang bisa langsung dijalankan
- Player dengan movement 8 arah (WASD / Arrow)
- World sederhana dengan objek collision
- Singleton `GameState` untuk data global awal (hari, energi, gold)

## Struktur folder

```text
project-game/
  scenes/
    main/Main.tscn
    player/Player.tscn
    world/World.tscn
  scripts/
    core/game_state.gd
    player/player.gd
  project.godot
```

## Cara jalanin

1. Buka project di Godot 4.6+
2. Tekan tombol Play (F5)
3. Karakter bisa digerakkan pakai WASD / Arrow

## Langkah berikutnya (roadmap pemula)

1. Tambah TileMap untuk tanah, jalan, air
2. Tambah tool system (cangkul, watering can, axe)
3. Tambah sistem inventory sederhana
4. Tambah siklus waktu (pagi-siang-malam)
5. Tambah crop growth per hari
6. Tambah NPC dan dialog

## Catatan

- Saat ini visual masih placeholder bentuk sederhana agar fokus ke fondasi gameplay dulu.
- Semua file aman untuk dikembangkan bertahap.
