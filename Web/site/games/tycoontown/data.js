// Static data for Tycoon Town: avatars, board tiles, surprise cards, stickers, goals.
export const AVATARS = [
  { id: 'fox', name: 'Pip', kind: 'fox', color: 0xff8a3d, css: '#ff8a3d', fur: 0xffa04d, belly: 0xfff3e0 },
  { id: 'bunny', name: 'Bonbon', kind: 'bunny', color: 0xff6fae, css: '#ff6fae', fur: 0xfff2f7, belly: 0xffd5e8 },
  { id: 'frog', name: 'Gus', kind: 'frog', color: 0x4fcf5f, css: '#4fcf5f', fur: 0x6fdc6a, belly: 0xe9ffd8 },
  { id: 'penguin', name: 'Mochi', kind: 'penguin', color: 0x3fa4ff, css: '#3fa4ff', fur: 0x3b6fd6, belly: 0xffffff },
];

export const SETS = {
  brown: { name: 'Cozy Lane', hex: 0xa8683f, css: '#a8683f', size: 2 },
  sky: { name: 'Cloud Court', hex: 0x6fd0ff, css: '#6fd0ff', size: 3 },
  pink: { name: 'Candy Row', hex: 0xff7ac0, css: '#ff7ac0', size: 3 },
  orange: { name: 'Snack Street', hex: 0xff9a3c, css: '#ff9a3c', size: 3 },
  red: { name: 'Pet Plaza', hex: 0xf05050, css: '#f05050', size: 3 },
  yellow: { name: 'Fun Fair', hex: 0xffd93b, css: '#f5c400', size: 3 },
  green: { name: 'Wild Park', hex: 0x4fc96a, css: '#3fb85a', size: 3 },
  blue: { name: 'Dream Hill', hex: 0x4b7cff, css: '#4b7cff', size: 2 },
  station: { name: 'Choo-Choo Line', hex: 0x6b6f80, css: '#6b6f80', size: 4 },
  util: { name: 'Power Pals', hex: 0x8a7cff, css: '#8a7cff', size: 2 },
};

const P = (i, name, price, set, kind = 'prop') => ({ i, type: kind, name, price, set });
export const TILES = (() => {
  const t = new Array(40);
  const put = (o) => { t[o.i] = o; };
  put({ i: 0, type: 'start', name: 'START' });
  put(P(1, 'Bakery', 60, 'brown')); put({ i: 2, type: 'dig', name: 'Treasure Dig' });
  put(P(3, 'Pancake Hut', 60, 'brown')); put({ i: 4, type: 'tax', name: 'Pet Spa', fee: 100, glyph: 'paw' });
  put(P(5, 'North Station', 200, 'station', 'station')); put(P(6, 'Ice Cream Cart', 100, 'sky'));
  put({ i: 7, type: 'surprise', name: 'Surprise' }); put(P(8, 'Juice Bar', 100, 'sky')); put(P(9, 'Cupcake Corner', 120, 'sky'));
  put({ i: 10, type: 'nap', name: 'Nap Corner' });
  put(P(11, 'Toy Shop', 140, 'pink')); put(P(12, 'Sunny Solar', 150, 'util', 'util')); put(P(13, 'Doll House', 140, 'pink')); put(P(14, 'Book Nook', 160, 'pink'));
  put(P(15, 'East Station', 200, 'station', 'station')); put(P(16, 'Pizzeria', 180, 'orange')); put({ i: 17, type: 'dig', name: 'Treasure Dig' });
  put(P(18, 'Noodle Bar', 180, 'orange')); put(P(19, 'Taco Truck', 200, 'orange'));
  put({ i: 20, type: 'park', name: 'Picnic Park' });
  put(P(21, 'Pet Store', 220, 'red')); put({ i: 22, type: 'surprise', name: 'Surprise' }); put(P(23, 'Flower Shop', 220, 'red')); put(P(24, 'Bike Shop', 240, 'red'));
  put(P(25, 'South Station', 200, 'station', 'station')); put(P(26, 'Cinema', 260, 'yellow')); put(P(27, 'Arcade', 260, 'yellow'));
  put(P(28, 'Water Works', 150, 'util', 'util')); put(P(29, 'Bowling Alley', 280, 'yellow'));
  put({ i: 30, type: 'gonap', name: 'Sleepy Time' });
  put(P(31, 'Aquarium', 300, 'green')); put(P(32, 'Petting Zoo', 300, 'green')); put({ i: 33, type: 'dig', name: 'Treasure Dig' });
  put(P(34, 'Science Lab', 320, 'green')); put(P(35, 'West Station', 200, 'station', 'station'));
  put({ i: 36, type: 'surprise', name: 'Surprise' }); put(P(37, 'Castle Hotel', 350, 'blue'));
  put({ i: 38, type: 'tax', name: 'Bubble Tea', fee: 75, glyph: 'cherry' }); put(P(39, 'Rocket Port', 400, 'blue'));
  return t;
})();
export const OWNABLE = TILES.filter((t) => t.price).map((t) => t.i);
export const levelName = ['For sale', 'House', 'Apartment', 'Skyscraper'];
export const rentFactor = [0, 0.1, 0.3, 0.75];
export const upgradeCost = (t, toLevel) => Math.round((t.price * (toLevel === 2 ? 0.5 : 0.9)) / 10) * 10;

export const CARDS = [
  { id: 'found', text: 'You found $100 under the couch cushions!', cash: 100, glyph: 'coin' },
  { id: 'sunny', text: 'Sunny day! Lemonade sales earn $150.', cash: 150, glyph: 'sun' },
  { id: 'party', text: 'Birthday party! Every friend gives you $25.', each: 25, glyph: 'balloon' },
  { id: 'spill', text: 'Oops, ice cream spill! Pay $50 for napkins.', cash: -50, glyph: 'cupcake' },
  { id: 'start', text: 'A rainbow shortcut! Zoom to START and collect your pay.', goto: 0, glyph: 'rainbow' },
  { id: 'fwd', text: 'Gust of wind! Float forward 3 spaces.', move: 3, glyph: 'cloud' },
  { id: 'back', text: 'Boing! A trampoline sends you back 3 spaces.', move: -3, glyph: 'bolt' },
  { id: 'train', text: 'All aboard! Ride to the next station.', station: true, glyph: 'rocket' },
  { id: 'free', text: 'Builder pals! Upgrade one of your buildings for free.', freeUp: true, glyph: 'house' },
  { id: 'sticker', text: 'A sticker pack floats down from the sky!', sticker: true, glyph: 'star' },
  { id: 'map', text: 'You found a treasure map! Time to dig!', dig: true, glyph: 'gem' },
  { id: 'wheel', text: 'A bonus wheel appears! Spin it!', wheel: true, glyph: 'flower' },
  { id: 'gift', text: 'You throw a surprise party! Give each friend $15.', give: 15, glyph: 'heart' },
  { id: 'tip', text: 'A tourist tips you $75 for directions.', cash: 75, glyph: 'note' },
];

export const STICKERS = [
  { id: 'heart', name: 'Sweet Heart', glyph: 'heart', rar: 0, c: ['#ff9ec4', '#ff5c9c'] },
  { id: 'star', name: 'Lucky Star', glyph: 'star', rar: 0, c: ['#ffe27a', '#ffb62e'] },
  { id: 'moon', name: 'Sleepy Moon', glyph: 'moon', rar: 0, c: ['#a9b8ff', '#6a76e8'] },
  { id: 'sun', name: 'Happy Sun', glyph: 'sun', rar: 0, c: ['#ffe27a', '#ff9f3a'] },
  { id: 'cloud', name: 'Fluffy Cloud', glyph: 'cloud', rar: 0, c: ['#d5f0ff', '#8fd0ff'] },
  { id: 'flower', name: 'Daisy', glyph: 'flower', rar: 0, c: ['#ffd6f0', '#ff8ccb'] },
  { id: 'fish', name: 'Goldfish', glyph: 'fish', rar: 0, c: ['#ffc58a', '#ff8a3d'] },
  { id: 'cupcake', name: 'Cupcake', glyph: 'cupcake', rar: 0, c: ['#ffd6e0', '#ff86a8'] },
  { id: 'balloon', name: 'Balloon', glyph: 'balloon', rar: 0, c: ['#ffb0b0', '#ff5a5a'] },
  { id: 'leaf', name: 'Little Leaf', glyph: 'leaf', rar: 0, c: ['#c6f5a8', '#5fcf5f'] },
  { id: 'paw', name: 'Paw Print', glyph: 'paw', rar: 0, c: ['#ffd9b0', '#e08a4a'] },
  { id: 'cherry', name: 'Cherries', glyph: 'cherry', rar: 0, c: ['#ffc0c8', '#f0506a'] },
  { id: 'house', name: 'Tiny House', glyph: 'house', rar: 1, c: ['#c9f0ff', '#4fb4f0'] },
  { id: 'bell', name: 'Jingle Bell', glyph: 'bell', rar: 1, c: ['#fff0a0', '#f2b81c'] },
  { id: 'note', name: 'Music Note', glyph: 'note', rar: 1, c: ['#e0c8ff', '#9a6cf0'] },
  { id: 'bolt', name: 'Zippy Bolt', glyph: 'bolt', rar: 1, c: ['#fff3a0', '#ffc61a'] },
  { id: 'rocket', name: 'Rocket', glyph: 'rocket', rar: 2, c: ['#c8d8ff', '#5a7cf0'] },
  { id: 'rainbow', name: 'Rainbow', glyph: 'rainbow', rar: 2, c: ['#e8f6ff', '#9ad8ff'] },
  { id: 'gem', name: 'Sparkle Gem', glyph: 'gem', rar: 2, c: ['#c0fff0', '#2ed8b0'] },
  { id: 'crown', name: 'Tycoon Crown', glyph: 'crown', rar: 3, c: ['#fff0a0', '#ffb400'] },
];
export const RARITY = ['Common', 'Rare', 'Epic', 'Legendary'];

export const GOALS = [
  { id: 'buy', name: 'Home Owner', desc: 'Buy 6 properties', need: 6, reward: 'house' },
  { id: 'sets', name: 'Set Master', desc: 'Complete 2 colour sets', need: 2, reward: 'rainbow' },
  { id: 'sky', name: 'Sky High', desc: 'Build 2 skyscrapers', need: 2, reward: 'rocket' },
  { id: 'dig', name: 'Treasure Hunter', desc: 'Dig up 6 treasures', need: 6, reward: 'gem' },
  { id: 'rent', name: 'Rent Collector', desc: 'Collect $1000 in rent', need: 1000, reward: 'bell' },
  { id: 'win', name: 'Town Champion', desc: 'Win a game', need: 1, reward: 'crown' },
];
