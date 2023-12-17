import { CONST } from '../const/const'
import { IGraphicsConstructor } from '../interfaces/graphics.interface'

export class Apple extends Phaser.GameObjects.Graphics {
    constructor({ scene, options }: IGraphicsConstructor) {
        super(scene, options)
        this.x = options.x
        this.y = options.y
        this.fillStyle(0xff0000, 0.8)
        this.fillRoundedRect(
            CONST.FIELD_SIZE,
            CONST.FIELD_SIZE,
            CONST.FIELD_SIZE,
            CONST.FIELD_SIZE,
            CONST.FIELD_SIZE / 2,
        )
        this.scene.add.existing(this)
    }

    public newApplePosition(x: number, y: number): void {
        this.x = x
        this.y = y
    }
}
