// Item catalogue for Buddy Playground. mode: melee | throw | aim | tap | hold | place
export const CATS = [
  { id: 'soft', name: 'Soft', icon: 'bat' }, { id: 'booms', name: 'Booms', icon: 'rocket' }, { id: 'liquids', name: 'Liquids', icon: 'water' },
  { id: 'foods', name: 'Foods', icon: 'pie' }, { id: 'objects', name: 'Objects', icon: 'duck' }, { id: 'machines', name: 'Machines', icon: 'fan' },
  { id: 'animals', name: 'Animals', icon: 'penguin' }, { id: 'magic', name: 'Magic', icon: 'lightning' }, { id: 'spooky', name: 'Spooky', icon: 'ghost' },
];
const M = (id, name, cat, price, o) => ({ id, name, cat, price, mode: 'melee', ...o });
const T = (id, name, cat, price, o) => ({ id, name, cat, price, mode: 'throw', ...o });
export const ITEMS = [
  // foam and soft
  M('bat', 'Foam Bat', 'soft', 0, { r: 80, pw: 15, pts: 12, type: 'smash', sfx: 'boing' }),
  M('pillow', 'Pillow', 'soft', 0, { r: 95, pw: 10, pts: 8, type: 'soft', sfx: 'pop', puff: 1 }),
  M('rollpin', 'Rolling Pin', 'soft', 60, { r: 75, pw: 16, pts: 14, type: 'smash', sfx: 'boing' }),
  M('hammer', 'Rubber Hammer', 'soft', 40, { r: 70, pw: 17, pts: 16, type: 'smash', sfx: 'boing', squeak: 1 }),
  M('sword', 'Foam Sword', 'soft', 80, { r: 95, pw: 13, pts: 13, type: 'slap', sfx: 'swish' }),
  M('plunger', 'Plunger', 'soft', 100, { r: 70, pw: 15, pts: 13, type: 'smash', sfx: 'pop', suck: 1 }),
  M('glove', 'Boxing Glove', 'soft', 220, { r: 115, pw: 28, pts: 30, type: 'smash', sfx: 'boom', scared: 1, big: 1 }),
  { id: 'feather', name: 'Tickle Feather', cat: 'soft', price: 30, mode: 'hold' },
  M('claws', 'Paper Claws', 'soft', null, { r: 70, pw: 5, pts: 4, type: 'tickle', sfx: 'swish', daily: 1 }),
  // fireworks and booms
  { id: 'popper', name: 'Party Popper', cat: 'booms', price: 0, mode: 'tap' },
  { id: 'poppergun', name: 'Popper Gun', cat: 'booms', price: 130, mode: 'aim', proj: 'confetti' },
  T('grenade', 'Confetti Grenade', 'booms', 150, { r: 17, fx: 'bomb', fuse: 1.5, pts: 18, type: 'boom', blast: 170, push: 11, burst: 'confetti' }),
  { id: 'rocket', name: 'Rocket Firework', cat: 'booms', price: 200, mode: 'aim', proj: 'rocket' },
  T('bouncybomb', 'Bouncy Bomb', 'booms', 250, { r: 19, fx: 'bomb', fuse: 2.4, rest: 0.92, pts: 22, type: 'boom', blast: 190, push: 13, burst: 'sparks' }),
  T('nuke', 'Glitter Nuke', 'booms', 4, { cur: 'gold', r: 21, fx: 'bomb', fuse: 1.9, pts: 40, type: 'boom', blast: 340, push: 20, burst: 'glitter', big: 1, scared: 1 }),
  // liquids
  { id: 'waterpistol', name: 'Water Pistol', cat: 'liquids', price: 70, mode: 'aim', proj: 'water' },
  T('water', 'Water Balloon', 'liquids', 20, { r: 17, fx: 'water', pts: 9, type: 'liquid' }),
  T('peasoup', 'Pea Soup', 'liquids', 90, { r: 18, fx: 'splat', cols: ['#8cd45a', '#b4ec80'], pts: 9, type: 'liquid', peas: 1, say: 'yuck' }),
  T('slime', 'Slime', 'liquids', 120, { r: 18, fx: 'splat', cols: ['#7ae04a', '#a8f27a'], pts: 10, type: 'liquid', floppy: 1 }),
  T('paint', 'Paint Splat', 'liquids', 110, { r: 17, fx: 'splat', cols: ['#b57bff', '#e0c8ff'], rainbow: 1, pts: 9, type: 'liquid' }),
  { id: 'icebucket', name: 'Ice Bucket', cat: 'liquids', price: 180, mode: 'tap' },
  { id: 'hose', name: 'Fire Hose', cat: 'liquids', price: 300, mode: 'hold' },
  { id: 'bubble', name: 'Bubble Wand', cat: 'liquids', price: 160, mode: 'hold' },
  // foods
  T('pie', 'Cream Pie', 'foods', 15, { r: 19, fx: 'splat', cols: ['#fffaf0', '#ffd6e6'], pts: 8, type: 'food', say: 'pie' }),
  T('tomato', 'Tomato', 'foods', 35, { r: 17, fx: 'splat', cols: ['#ff4d4d', '#ff8a8a'], pts: 8, type: 'food' }),
  T('cupcake', 'Cupcake', 'foods', 50, { r: 18, fx: 'feed', heal: 12, pts: 5, type: 'food', crumbs: ['#ff9ec7', '#ffd2e6', '#8fe3ff'] }),
  T('icecream', 'Ice Cream', 'foods', 60, { r: 17, fx: 'feed', heal: 12, pts: 5, type: 'food', crumbs: ['#ffa8d2', '#a8f0d0', '#fff'] }),
  T('pizza', 'Pizza Slice', 'foods', 70, { r: 19, fx: 'feed', heal: 15, pts: 6, type: 'food', crumbs: ['#ffcf5a', '#e8283e', '#e6a040'] }),
  { id: 'cupcakecannon', name: 'Cupcake Cannon', cat: 'foods', price: 220, mode: 'aim', proj: 'cupcake' },
  // objects
  T('blocks', 'Toy Blocks', 'objects', 40, { shape: 'r', w: 28, h: 28, n: 3, fx: 'bounce', pts: 8, type: 'smash', life: 12 }),
  T('bouncyball', 'Bouncy Balls', 'objects', 45, { r: 16, n: 3, rest: 0.96, fx: 'bounce', pts: 6, type: 'smash', life: 12 }),
  T('duck', 'Rubber Duck', 'objects', 55, { r: 20, rest: 0.6, fx: 'bounce', pts: 7, type: 'soft', life: 14, squeak: 1 }),
  T('beach', 'Beach Ball', 'objects', 80, { r: 40, rest: 0.95, fx: 'bounce', pts: 8, type: 'soft', life: 14, light: 1 }),
  { id: 'balloons', name: 'Balloons', cat: 'objects', price: 90, mode: 'tap' },
  // machines
  { id: 'fan', name: 'Spinning Fan', cat: 'machines', price: 100, mode: 'hold' },
  { id: 'tramp', name: 'Trampoline', cat: 'machines', price: 60, mode: 'place' },
  { id: 'mushroom', name: 'Bouncy Mushroom', cat: 'machines', price: 90, mode: 'place' },
  { id: 'spring', name: 'Spring Launcher', cat: 'machines', price: 160, mode: 'place' },
  { id: 'conveyor', name: 'Conveyor', cat: 'machines', price: 220, mode: 'place' },
  { id: 'magnet', name: 'Big Magnet', cat: 'machines', price: 180, mode: 'hold' },
  { id: 'vice', name: 'Squish Walls', cat: 'machines', price: 350, mode: 'tap' },
  // animals
  { id: 'butterflies', name: 'Butterflies', cat: 'animals', price: 100, mode: 'tap' },
  { id: 'bees', name: 'Silly Bees', cat: 'animals', price: 250, mode: 'tap' },
  { id: 'penguin', name: 'Penguin Slide', cat: 'animals', price: 300, mode: 'tap' },
  { id: 'dino', name: 'Dino Stomp', cat: 'animals', price: 5, cur: 'gold', mode: 'tap', scared: 1, big: 1 },
  // magic
  { id: 'raincloud', name: 'Rain Cloud', cat: 'magic', price: 200, mode: 'tap' },
  { id: 'lightning', name: 'Zap Bolt', cat: 'magic', price: 350, mode: 'tap' },
  { id: 'tornado', name: 'Tornado', cat: 'magic', price: 500, mode: 'tap' },
  { id: 'hand', name: 'Giant Hand', cat: 'magic', price: 4, cur: 'gold', mode: 'tap', scared: 1, big: 1 },
  { id: 'meteor', name: 'Marshmallow Meteors', cat: 'magic', price: 450, mode: 'tap', scared: 1 },
  { id: 'torch', name: 'Sparkly Torch', cat: 'magic', price: null, mode: 'hold', daily: 1 },
  // spooky fun
  { id: 'ghost', name: 'Friendly Ghosts', cat: 'spooky', price: 150, mode: 'tap' },
  T('pumpkin', 'Pumpkin Head', 'spooky', 120, { r: 24, rest: 0.5, fx: 'bounce', pts: 10, type: 'smash', life: 14, boo: 1 }),
  { id: 'skeleton', name: 'Silly Skeleton', cat: 'spooky', price: 200, mode: 'tap' },
];
export const ITEM = Object.fromEntries(ITEMS.map((i) => [i.id, i]));
export const SHORT = { bat: 'Foam Bat', pillow: 'Pillow', rollpin: 'Rolling Pin', hammer: 'Hammer', sword: 'Foam Sword', plunger: 'Plunger', glove: 'Big Glove', feather: 'Tickle', claws: 'Claws', popper: 'Popper', poppergun: 'Popper Gun', grenade: 'Grenade', rocket: 'Rocket', bouncybomb: 'Bouncy Bomb', nuke: 'Glitter Nuke', waterpistol: 'Water Pistol', water: 'Water', peasoup: 'Pea Soup', slime: 'Slime', paint: 'Paint', icebucket: 'Ice Bucket', hose: 'Fire Hose', bubble: 'Bubbles', pie: 'Cream Pie', tomato: 'Tomato', cupcake: 'Cupcake', icecream: 'Ice Cream', pizza: 'Pizza', cupcakecannon: 'Cake Cannon', blocks: 'Blocks', bouncyball: 'Bouncy Balls', duck: 'Duck', beach: 'Beach Ball', balloons: 'Balloons', fan: 'Fan', tramp: 'Trampoline', mushroom: 'Mushroom', spring: 'Spring', conveyor: 'Conveyor', magnet: 'Magnet', vice: 'Squish', butterflies: 'Butterflies', bees: 'Bees', penguin: 'Penguins', dino: 'Dino', raincloud: 'Rain Cloud', lightning: 'Zap', tornado: 'Tornado', hand: 'Giant Hand', meteor: 'Meteors', torch: 'Torch', ghost: 'Ghosts', pumpkin: 'Pumpkin', skeleton: 'Skeleton' };
export const DECOR_PRICES = { box: 0 };
