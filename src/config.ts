import { BootScene } from './scenes/boot-scene'
import { GameScene } from './scenes/game-scene'
import { MainMenuScene } from './scenes/main-menu-scene'

export const GameConfig: Phaser.Types.Core.GameConfig = {
    title: 'Pacmaze',
    version: '2.0',
    width: 256 * 3,
    height: 224 * 3,
    zoom: 1,
    type: Phaser.AUTO,
    parent: 'game',
    scene: [BootScene, MainMenuScene, GameScene],
    input: {
        keyboard: true,
        mouse: false,
        touch: false,
        gamepad: false
    },
    backgroundColor: '#000000',
    render: {
        pixelArt: false,
        antialias: false
    }
}
