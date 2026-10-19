// Change this to 'WEB-02' when deploying to your second server.
const SERVER_NAME = window.__SERVER_NAME__ || 'LOCAL DEV'
const drinks = [
  { name: 'Classic Espresso', note: 'Small cup. Big character.', description: 'A rich, full-bodied shot with notes of dark chocolate and a golden crema.', price: '3.00', type: 'espresso', tag: 'THE ORIGINAL' },
  { name: 'Honey Oat Latte', note: 'Your new morning ritual.', description: 'Velvety oat milk, our signature espresso, and a little golden honey.', price: '5.50', type: 'latte', tag: 'CAFÉ FAVORITE' },
  { name: 'Cloud Cappuccino', note: 'A little cup of comfort.', description: 'Equal parts bold espresso, steamed milk, and a soft cloud of foam.', price: '4.50', type: 'cappuccino' },
  { name: 'Slow Brew Cold Brew', note: 'Good things take time.', description: 'Steeped slowly for 18 hours. Smooth, refreshing, and served over ice.', price: '4.50', type: 'cold' },
  { name: 'Strawberry Matcha', note: 'A fresh kind of energy.', description: 'Earthy matcha meets sweet strawberry and creamy milk. Spring in a glass.', price: '6.00', type: 'matcha', tag: 'A TASTE OF SPRING' },
  { name: 'Cozy Hot Chocolate', note: 'Happiness, by the cup.', description: 'Real cocoa, warm milk, and a generous swirl of whipped cream.', price: '4.50', type: 'chocolate' },
]

function Cup({ type = 'latte' }) {
  return <div className={`drink-art ${type}`} aria-hidden="true"><div className="cup-shadow" /><div className="saucer" /><div className="cup"><div className="coffee-surface"><span>✦</span></div><div className="cup-mark">s.</div></div></div>
}

function App() {
  return (
    <>
      <div className="topline"><span>A little pause. A lovely cup.</span><span className="server-badge"><i />Served by: {SERVER_NAME}</span></div>
      <header className="site-header page-width">
        <a className="wordmark" href="#home" aria-label="Spring Café home"><span className="brand-flower">✳</span> spring<span className="brand-cafe">CAFÉ</span></a>
        <nav aria-label="Main navigation" className="flex items-center gap-5 sm:gap-9"><a href="#menu">Our menu</a><a href="#about">Our story</a><a className="nav-visit" href="#visit">Come say hello <span aria-hidden="true">↗</span></a></nav>
      </header>
      <main id="home">
        <section className="hero page-width">
          <div className="hero-copy"><p className="eyebrow"><span /> YOUR DAILY DOSE OF SOMETHING GOOD</p><h1>Good coffee.<br />Better <em>days.</em><span className="headline-star" aria-hidden="true">✳</span></h1><p className="hero-description">Slow mornings, thoughtful coffee, and a space to just be. Find your little moment of spring, any day of the year.</p><div className="flex flex-wrap gap-3"><a className="button button-green" href="#menu">Find your favorite <span aria-hidden="true">↗</span></a><a className="button button-outline" href="#about">A little about us <span aria-hidden="true">→</span></a></div><div className="hero-footnote"><span className="small-flower" aria-hidden="true">✳</span> Crafted with care. Always.</div></div>
          <div className="hero-visual"><div className="visual-grain" /><span className="visual-caption">FRESHLY BREWED · HAPPILY SIPPED</span><div className="hero-ring" /><div className="hero-cup"><Cup /></div><div className="round-seal">a cup of<br /><strong>happy</strong><span>✦</span></div><div className="coffee-bean bean-one" /><div className="coffee-bean bean-two" /><div className="visual-bottom"><span>THE EVERYDAY, MADE LOVELY.</span><span>EST. 2024</span></div></div>
        </section>
        <div className="values-strip" aria-label="Our values"><span>Thoughtfully sourced</span><b aria-hidden="true">✳</b><span>Lovingly brewed</span><b aria-hidden="true">✳</b><span>Everyone welcome</span><b aria-hidden="true">✳</b><span>A little joy in every cup</span></div>
        <section id="menu" className="menu-section page-width"><div className="section-heading"><div><p className="eyebrow">THE GOOD STUFF</p><h2>Meet your next <em>favorite.</em></h2></div><p>Familiar comforts. Fresh little discoveries.<br />Made just right, just for you.</p></div><div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">{drinks.map(drink => <article key={drink.name} className="menu-card"><div className={`drink-stage stage-${drink.type}`}>{drink.tag && <span className="drink-tag">{drink.tag}</span>}<Cup type={drink.type} /><span className="stage-note">{drink.note}</span></div><div className="card-copy"><div className="flex items-start justify-between gap-3"><h3>{drink.name}</h3><span className="price">${drink.price}</span></div><p>{drink.description}</p></div></article>)}</div><p className="menu-footnote">A little something for everyone. Oat milk available for your favorite cup.</p></section>
        <section id="about" className="about-section page-width"><div className="about-art" aria-hidden="true"><span className="about-flower">✳</span><span className="about-art-text">take a breath.<br />take a sip.<br /><em>stay a while.</em></span><span className="about-art-bottom">YOUR NEIGHBORHOOD HAPPY PLACE</span></div><div className="about-copy"><p className="eyebrow">ROOTED IN THE LITTLE THINGS</p><h2>About our café.<br /><em>A space to bloom.</em></h2><p>We believe a good day can start with a simple cup of coffee. Spring Café is our little corner of calm — a place for catching up, slowing down, and making everyday moments feel special.</p><p>From carefully chosen beans to the warm hello at the door, we put a little extra love into everything we do. Pull up a chair. You belong here.</p><span className="about-signature">With love, the Spring team <span aria-hidden="true">♡</span></span></div></section>
      </main>
      <footer id="visit"><div className="footer-main page-width"><div><a className="wordmark" href="#home"><span className="brand-flower">✳</span> spring<span className="brand-cafe">CAFÉ</span></a><p>Good coffee. Good company.<br />A fresh start, every day.</p></div><div><h3>Find our little corner</h3><p>123 Bloom Street, Garden District<br /><a href="mailto:hello@springcafe.example">hello@springcafe.example</a><br /><a href="tel:+15550100123">+1 (555) 010-0123</a></p></div><div><h3>There’s always time for coffee</h3><p>Monday – Friday <span>7:00 am – 6:00 pm</span><br />Saturday – Sunday <span>8:00 am – 5:00 pm</span></p><span className="footer-note">Sample location & opening hours</span></div></div><div className="footer-bottom page-width"><span>© {new Date().getFullYear()} Spring Café. Brewed with love.</span><span>See you over a cup. <span aria-hidden="true">✳</span></span></div></footer>
    </>
  )
}

export default App
