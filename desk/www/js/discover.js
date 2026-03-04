// Cast - Discover: Curated podcast directory

const DISCOVER_FEEDS = [
  // Tech
  { title: 'Lex Fridman Podcast', feedUrl: 'https://lexfridman.com/feed/podcast/', imageUrl: 'https://lexfridman.com/wordpress/wp-content/uploads/powerpress/artwork_3000-230.png', category: 'Tech' },
  { title: 'Accidental Tech Podcast', feedUrl: 'https://atp.fm/episodes?format=rss', imageUrl: 'https://cdn.atp.fm/artwork', category: 'Tech' },
  { title: 'Syntax - Web Development', feedUrl: 'https://feed.syntax.fm/rss', imageUrl: 'https://ssl-static.libsyn.com/p/assets/0/0/e/3/00e3cd44cc1545/iTunes_Artwork.png', category: 'Tech' },
  { title: 'The Changelog', feedUrl: 'https://changelog.com/podcast/feed', imageUrl: 'https://cdn.changelog.com/uploads/covers/the-changelog-original.png', category: 'Tech' },
  { title: 'Software Engineering Daily', feedUrl: 'https://softwareengineeringdaily.com/feed/podcast/', imageUrl: 'https://softwareengineeringdaily.com/wp-content/uploads/2020/04/sed_avatar.jpg', category: 'Tech' },

  // News
  { title: 'The Daily (NYT)', feedUrl: 'https://feeds.simplecast.com/54nAGcIl', imageUrl: 'https://image.simplecastcdn.com/images/03d8b493-87fc-4bd1-931f-8a8e9b945c4a/27987606-cf5c-4249-84e2-63e95deb22cd/3000x3000/c_logo_2023august.jpg', category: 'News' },
  { title: 'Up First (NPR)', feedUrl: 'https://feeds.npr.org/510318/podcast.xml', imageUrl: 'https://media.npr.org/assets/img/2021/04/07/up-first_tile_npr-network-01_sq-80a3e14a7d16c18bc0e2e5e33801cf99bd5c7a80.jpg', category: 'News' },
  { title: 'BBC Global News Podcast', feedUrl: 'https://podcasts.files.bbci.co.uk/p02nq0gn.rss', imageUrl: 'https://ichef.bbci.co.uk/images/ic/3000x3000/p09vy5gk.jpg', category: 'News' },
  { title: 'All-In Podcast', feedUrl: 'https://feeds.megaphone.fm/all-in-with-chamath-jason-sacks-friedberg', imageUrl: 'https://megaphone.imgix.net/podcasts/c6df2a92-8e55-11eb-89cd-0b40d5480ef2/image/Podcast_All-In_Artwork_3000x3000.jpg', category: 'News' },

  // Comedy
  { title: 'Conan O\'Brien Needs a Friend', feedUrl: 'https://feeds.simplecast.com/dHoohVNH', imageUrl: 'https://image.simplecastcdn.com/images/60ab957c-1dcf-43c4-8793-fcf06f498dc7/5bb04ca5-0497-4513-afd8-9b0da8edc8a3/3000x3000/conan-s5.jpg', category: 'Comedy' },
  { title: 'SmartLess', feedUrl: 'https://feeds.simplecast.com/fN_gMVkP', imageUrl: 'https://image.simplecastcdn.com/images/6b62cad5-f8ee-4044-ba6c-2a04dffa28b1/f81e5d03-d2a9-405a-aac5-8a5c6a28faf8/3000x3000/smartless-cover-3000x3000.jpg', category: 'Comedy' },
  { title: 'Wait Wait... Don\'t Tell Me!', feedUrl: 'https://feeds.npr.org/344098539/podcast.xml', imageUrl: 'https://media.npr.org/assets/img/2022/09/23/wwdtm_tile_npr-network-01_sq-df32f4f066c0bc5be1a2b9a7b73b1c3a24b974ef.jpg', category: 'Comedy' },
  { title: 'Comedy Bang! Bang!', feedUrl: 'https://feeds.simplecast.com/bMuvnL_n', imageUrl: 'https://image.simplecastcdn.com/images/6620a4e1-d1f1-4c99-8d8f-e5a67de28043/8b893856-63b0-44db-8b90-f33c7e397b37/3000x3000/cbb-artwork-3000.jpg', category: 'Comedy' },

  // Science
  { title: 'Radiolab', feedUrl: 'https://feeds.simplecast.com/EmVW7VGp', imageUrl: 'https://image.simplecastcdn.com/images/10a3c21e-0d3e-4b01-87c9-8bcfe0f39670/6cd0ee1b-f437-4ca8-a571-0c4e35aa3e38/3000x3000/radiolab-2021.jpg', category: 'Science' },
  { title: 'Huberman Lab', feedUrl: 'https://feeds.megaphone.fm/hubermanlab', imageUrl: 'https://megaphone.imgix.net/podcasts/042e6144-725e-11eb-badf-c74096378b58/image/Huberman-Lab-Podcast-Thumbnail-3000x3000.jpg', category: 'Science' },
  { title: 'StarTalk Radio', feedUrl: 'https://feeds.simplecast.com/4T39_jAj', imageUrl: 'https://image.simplecastcdn.com/images/e9a566e7-d10c-4064-bcf6-f1dab66c9db6/3c13af8a-0aa8-46cf-ad60-73e4b6ee7e73/3000x3000/startalk-3000x3000.jpg', category: 'Science' },
  { title: 'Science Vs', feedUrl: 'https://feeds.megaphone.fm/sciencevs', imageUrl: 'https://megaphone.imgix.net/podcasts/e5c60544-e12f-11e6-b1e5-1786d42c6f29/image/ScienceVs_ShowArt.jpg', category: 'Science' },

  // History
  { title: 'Hardcore History', feedUrl: 'https://feeds.feedburner.com/dancarlin/history', imageUrl: 'https://image.simplecastcdn.com/images/7c895d2a-a1a8-4c48-b2e3-1cf2e3766ec4/a0560d49-2aa0-472a-a92d-26d39de26b51/3000x3000/hh-itunes-square-1400.jpg', category: 'History' },
  { title: 'Revolutions', feedUrl: 'https://revolutionspodcast.libsyn.com/rss', imageUrl: 'https://ssl-static.libsyn.com/p/assets/6/0/4/a/604abf5fee0c8c01/revolutions_cover_final.jpg', category: 'History' },
  { title: 'The Rest Is History', feedUrl: 'https://feeds.megaphone.fm/GLT1412515089', imageUrl: 'https://megaphone.imgix.net/podcasts/38d62068-7e08-11eb-b985-db65b95c1995/image/TRIH_podcast_tile_v2.jpg', category: 'History' },
  { title: 'History Extra', feedUrl: 'https://feeds.acast.com/public/shows/historyextra', imageUrl: 'https://assets.pippa.io/shows/6149d5e05817f1e7c4b5c824/1664265765490-cover.jpg', category: 'History' },

  // Business
  { title: 'How I Built This', feedUrl: 'https://feeds.npr.org/510313/podcast.xml', imageUrl: 'https://media.npr.org/assets/img/2022/09/23/hibt_tile_npr-network-01_sq-5e4b01ee87fa1a1e1a4ef3fba1c5612b6bd6ed59.jpg', category: 'Business' },
  { title: 'Planet Money', feedUrl: 'https://feeds.npr.org/510289/podcast.xml', imageUrl: 'https://media.npr.org/assets/img/2022/09/23/pm_tile_npr-network-01_sq-5e4b3ea0a1a2c6e7a5e4efb6c45e7a4a38e0d4ac.jpg', category: 'Business' },
  { title: 'Acquired', feedUrl: 'https://feeds.pacific-content.com/acquired', imageUrl: 'https://assets.pippa.io/shows/6111a5e27b51c88fb290e90a/1661536820715-cover.jpg', category: 'Business' },
  { title: 'Masters of Scale', feedUrl: 'https://rss.art19.com/masters-of-scale', imageUrl: 'https://content.production.cdn.art19.com/images/cf/df/3f/8b/cfdf3f8b-da4e-475d-b493-be0a7c60c48e/6ce5de7c08f72fa0a6d92ab35bff20ba.jpeg', category: 'Business' },

  // Culture
  { title: 'This American Life', feedUrl: 'https://www.thisamericanlife.org/podcast/rss.xml', imageUrl: 'https://www.thisamericanlife.org/sites/default/files/styles/square/public/tal-logo-2019-2.png', category: 'Culture' },
  { title: 'Freakonomics Radio', feedUrl: 'https://feeds.simplecast.com/Y8lFbOT4', imageUrl: 'https://image.simplecastcdn.com/images/0e218e0b-5c00-42ae-be5f-2e95fcee0480/0cf8e842-76e1-4df8-b35d-5ee41abfc18a/3000x3000/freakonomics-radio-tile.jpg', category: 'Culture' },
  { title: 'Hidden Brain', feedUrl: 'https://feeds.simplecast.com/kwWc0lhf', imageUrl: 'https://image.simplecastcdn.com/images/bf017760-f870-4ae0-89f6-e1a94c75d3b9/4508d76c-7e59-4f4e-9a08-5b54c1de2a13/3000x3000/hidden-brain-tile.jpg', category: 'Culture' },
  { title: 'The Moth', feedUrl: 'https://feeds.feedburner.com/themothpodcast', imageUrl: 'https://image.simplecastcdn.com/images/e7ee39b5-f088-4290-93a6-ecda8b37df4b/77e82b2e-5126-491c-ab7d-c1a4f3b96340/3000x3000/the-moth-3000.jpg', category: 'Culture' },
];

const DISCOVER_CATEGORIES = ['All', 'Tech', 'News', 'Comedy', 'Science', 'History', 'Business', 'Culture'];

const Discover = {
  currentCategory: 'All',

  render() {
    const container = document.getElementById('page-discover');
    const subscribedUrls = new Set((App.podcasts || []).map(p => p['feed-url']));

    const filtered = this.currentCategory === 'All'
      ? DISCOVER_FEEDS
      : DISCOVER_FEEDS.filter(f => f.category === this.currentCategory);

    container.innerHTML = `
      <h1>Discover</h1>
      <div class="discover-categories">
        ${DISCOVER_CATEGORIES.map(cat => `
          <button class="filter-btn ${cat === this.currentCategory ? 'active' : ''}"
                  onclick="Discover.setCategory('${cat}')">${cat}</button>
        `).join('')}
      </div>
      <div class="podcast-grid">
        ${filtered.map(f => {
          const isSubscribed = subscribedUrls.has(f.feedUrl);
          return `
            <div class="podcast-card discover-card">
              <img src="${App.escHtml(f.imageUrl)}" alt="${App.escHtml(f.title)}"
                   onerror="this.style.background='var(--bg-card)'; this.src=''">
              <div class="title">${App.escHtml(f.title)}</div>
              <div class="author">${App.escHtml(f.category)}</div>
              <button class="btn btn-small discover-sub-btn ${isSubscribed ? 'subscribed' : ''}"
                      onclick="Discover.subscribe('${App.escHtml(f.feedUrl)}')" ${isSubscribed ? 'disabled' : ''}>
                ${isSubscribed ? 'Subscribed' : 'Subscribe'}
              </button>
            </div>
          `;
        }).join('')}
      </div>
    `;
  },

  setCategory(cat) {
    this.currentCategory = cat;
    this.render();
  },

  async subscribe(feedUrl) {
    try {
      await CastAPI.subscribe(feedUrl);
      App.toast('Subscribing...');
      setTimeout(async () => {
        await App.loadPodcasts();
        this.render();
      }, 3000);
    } catch (e) {
      console.error(e);
      App.toast('Failed to subscribe', 'error');
    }
  }
};
