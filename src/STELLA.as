/**
 * Copyright spanvega ( http://wonderfl.net/user/spanvega )
 * MIT License ( http://www.opensource.org/licenses/mit-license.php )
 * From: http://wonderfl.net/c/xHXa
 */
package {
	import com.bit101.components.*;
	
	import flash.display.*;
	import flash.events.*;
	import flash.filters.*;
	import flash.geom.*;
	
	[ SWF(width = "465", height = "465", backgroundColor = "0x000000", frameRate = "50")]
	public class STELLA extends Sprite {
		// カラー値調整(R係数,　G係数, B係数, 透明度係数)  
		private var tran:ColorTransform = new ColorTransform(1, 1, 1, 0.95);
		
		// ぼかし効果(水平ぼかし量, 垂直ぼかし量, 品質)
		private var blur:BlurFilter = new BlurFilter(2.5, 2.5, 1);
		
		// ランダムな値
		private var seed:int = Math.random() * uint.MAX_VALUE; 
		
		private var p_vec:Vector.<PARTICLE> = new <PARTICLE>[];
		private var m_vec:Vector.<Matrix> = new <Matrix>[];
		private var blend:Vector.<String> = new <String>[];
		
		private var o:Array = [new Point(), new Point()];
		
		// 画面サイズ、halfは2で割った値
		private var size:int = 465, half:int = size >> 1;
		
		// 矩形(x, y, 幅, 高さ)
		private var rect:Rectangle = new Rectangle(0, 0, size, size);
		
		// チェックボックスの値
		private var emission:Boolean = true;
		
		// プログレスバー
		private var quantity:Number = 75;
		
		// 変化速度 下部左スライダーで変化
		private var velocity:Number = 5;
		
		// スピード 下部右バーで変化
		private var speed:Number = 1.5;
		
		// パーティクルの上限
		private var limit:int = 10000;
		
		private var image:BitmapData;
		private var pixel:BitmapData;
		private var model:BitmapData;
		
		// プログレスバー
		private var q:ProgressBar;
		
		// ラジアン
		private var rad:Number;
		// パーティクルの個数
		private var num:Number;
		
		private var m:Matrix, s:String;
		private var p:PARTICLE;
		
		// 各RGB要素
		private var r:Number, g:Number,b:Number
		// setPixel32()で格納するARGB
		private var c:uint;
		
		private var i:int;
		
		
		public function STELLA() {
			// stageがあるならそのままinit()を、ないなら読み込んだ後init()を実行
			stage ? init() : addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init():void {
			// 指定のイベントリスナが存在する場合
			if(hasEventListener(Event.ADDED_TO_STAGE)) {
				// 不要なイベントリスナを削除
				removeEventListener(Event.ADDED_TO_STAGE, init);
			}
			
			stage.scaleMode = "noScale";
			
			m_vec.push(
				// 上の三角形
				//  1  1  half
				// -1  1 -half 
				new Matrix(1, 1, -1, 1, half, -half),
				
				// 右の三角形
				// -1 -1  half*3
				// -1  1 -half
				new Matrix(-1, -1, -1, 1, half * 3, half),
				
				// 下の三角形
				// -1 -1  half
				// 　1 -1 -half*3
				new Matrix(-1, -1, 1, -1, half, half * 3),
				
				// 左の三角形
				// 　1  1 -half
				// 　1 -1  half
				new Matrix(1, 1, 1, -1, -half, half)
			);
			
			blend.push(
				// INVERT=背景反転    HARDLIGHT=シャドウ効果
				BlendMode.INVERT,   BlendMode.HARDLIGHT,
				// MULTIPLY=乗算
				BlendMode.MULTIPLY, BlendMode.MULTIPLY
			);
			
			// ビットマップデータ(幅, 高さ, 透明度, 色)
			model = new BitmapData(half, half, false, 0);
			image = new BitmapData(size, size, true, 0);
			pixel = image.clone();
			
			addChild(new Bitmap(image));
			addChild(new Bitmap(pixel));
			
			gui();
			
			// frameメソッドへエンタフレームイベントを追加
			frame();stage.addEventListener(Event.ENTER_FRAME, frame);
		}
		// エンターフレームメソッド
		private function frame(e:Event = null):void {
			o[1].x = -(o[0].x += speed);
			o[1].y = -(o[0].y -= speed);
			
			// --o CANVAS
			
			// perlinノイズ生成(幅周波数, 高さ周波数, 重ね回数, ランダムシード, エッジをスムーズ, フラクタルを生成,
			//               [カラーチャンネル], [グレースケール], [オフセット配列])
			model.perlinNoise(233, 233, 2, seed, true, false, 7, false, o);
			
			// blend内にある4種類のフィルタを描画
			for each(s in blend) {
				model.draw(model, null, null, s);
			}
			
			// m_vecにある4種類のMatrix情報に従い描画
			for each(m in m_vec) {
				image.draw(model, m);
			}
			
			// --o PIXELS
			// ピクセル操作のためロック
			pixel.lock();
			// pixelのrect位置のカラー情報(tran)を調整
			pixel.colorTransform(rect, tran);
			// フィルタを適用(ソースイメージ, ソース矩形, ターゲットポイント, フィルタ)
			pixel.applyFilter(pixel, rect, rect.topLeft, blur);
			
			// p_vec内の全パーティクルを参照
			// パーティクルの位置の色情報より移動先を決定
			for each(p in p_vec) {
				// パーティクルの位置の色を取得
				c = image.getPixel(p.x, p.y);
				// 0x112233の場合、0x11 / 0x80
				r = (c <<  8 >>> 24) / 0x80;
				g = (c << 16 >>> 24) / 0x80;
				b = (c << 24 >>> 24) / 0x40;

				p.x += p.vx * (r - b);
				p.y += p.vy * (g - b);
				
				pixel.setPixel32(p.x, p.y, p.c);
				
				// パーティクルが画面端に出たら、該当するパーティクルを消す
				if(p.y < 0 || p.y > size || p.x < 0 || p.x > size) {
					p_vec.splice(p_vec.indexOf(p), 1); p = null;
				}
			}
			
			// チェックボックスにチェックが入っており、パーティクルの数がlimitより多い場合
			if(emission == true && p_vec.length < limit) {
				// パーティクルの数を調整
				num = quantity % (limit - p_vec.length)
			} else {
				num = 0;
			}
			
			for(i = 0; i < num; i++) {
				p = new PARTICLE();
				// 色をランダム	
				p.c = 0xFFFFFFFF * Math.random();
				// マウスに位置に出現させる
				p.x = stage.mouseX;
				p.y = stage.mouseY;
				// ランダムな角度からラジアンへ変換
				rad = (Math.random() * 360) * (3.1415926535 / 180);
				// 移動先のx座標
				p.vx = Math.cos(rad) * velocity;
				// 移動先のy座標
				p.vy = Math.sin(rad) * velocity;
				
				p_vec.push(p);
			}

			pixel.unlock();
			// プログレスバーの値にパーティクルの数を入れる
			q.value = p_vec.length / limit;
		}
		
		// 下部バーを描画
		private function gui():void {
			// 下部バーの色を設定
			with(Style) {
				BACKGROUND  = LABEL_TEXT = DROPSHADOW = 0xFFFFFF;
				BUTTON_FACE = PROGRESS_BAR            = 0x000000;
			}
			
			with(addChild(new Sprite())) {
				// 塗りつぶし(色, 透明度)
				graphics.beginFill(0x000000, 0.5);
				
				// 矩形(x座標, y座標, 幅, 高さ)
				graphics.drawRect(0, 440, 465, 25);
			}
			
			
			// 左下スライダー(表示リストに加える親オブジェクト, x座標, y座標, ラベル, デフォルトハンドラ)
			var w:HUISlider = new HUISlider(this, 10, 443, "VELOCITY", function():void { velocity = w.value });
			with(w) {
				// 値決定(最小値, 最大値, 現在値)
				setSliderParams(1, 10, velocity);
				// 幅
				width = 160;
				// 小数点第何位まで使うか
				labelPrecision = 2;
				// 変化単位
				tick = 0.01;
				// スライダーを描画
				draw();
			}
			
			// 左下スライダー 上記のものと同じ場所に配置
			var s:HUISlider = new HUISlider(this, 10, 443, "SPEED", function():void { speed = s.value });
			with(s) {
				setSliderParams(-2.5, 2.5, speed);
				width = 160;
				labelPrecision = 2;
				draw();
			}
			
			// チェックボックス(表示リストに加える親オブジェクト, x座標, y座標, ラベル, デフォルトハンドラ)
			var c:CheckBox = new CheckBox(this, 333, 447, "", function():void { emission = c.selected; });
			c.selected = emission;
			
			// 右下プログレスバー(表示リストに加える親オブジェクト, x座標, y座標)
			q = new ProgressBar(this, 353, 447);
			with(q) {
				height = 10;
				draw();
			}
		}
	}
	
}