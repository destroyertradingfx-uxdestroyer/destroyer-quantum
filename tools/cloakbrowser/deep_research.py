#!/usr/bin/env python3
"""
DESTROYER QUANTUM — Deep Research Browser
Use this when you need to investigate WHY the EA performed poorly,
research market conditions, or analyze what happened on a specific date.

NOT automated — this is a tool for the AI agent to use on demand.

Usage from Python:
    from deep_research import DeepResearch
    r = DeepResearch()
    r.investigate_date("2025-01-15")           # What happened on this date?
    r.research_eurusd("ECB rate decision")     # Research a topic
    r.check_twitter("EURUSD crash")            # X/Twitter search
    r.check_youtube("EURUSD analysis January") # YouTube search
    r.check_forexfactory("2025-01-15")         # Economic events
    r.check_news("EURUSD")                     # Financial news
    r.full_postmortem("2025-01-10", "2025-01-15")  # Full analysis of a period
"""

import sys
import json
import time
from datetime import datetime, timedelta
from pathlib import Path

OUTPUT_DIR = Path("/home/ubuntu/destroyer-quantum/tools/cloakbrowser/output")
OUTPUT_DIR.mkdir(exist_ok=True)


class DeepResearch:
    """Deep research browser for DESTROYER QUANTUM post-mortem analysis."""
    
    def __init__(self):
        from cloakbrowser import launch
        self.browser = launch(headless=True)
        self._page = None
    
    def _get_page(self):
        if self._page is None or self._page.is_closed():
            self._page = self.browser.new_page()
        return self._page
    
    def _search(self, url, wait=3):
        """Navigate to URL and return page content."""
        page = self._get_page()
        try:
            page.goto(url, timeout=30000)
            time.sleep(wait)
            return page
        except Exception as e:
            print(f"Navigation error: {e}")
            return None
    
    def _extract_text(self, selector="body", max_chars=5000):
        """Extract text from a page element."""
        page = self._get_page()
        try:
            el = page.query_selector(selector)
            if el:
                text = el.inner_text()
                return text[:max_chars]
        except:
            pass
        return ""
    
    # =========================================================
    # RESEARCH METHODS
    # =========================================================
    
    def check_twitter(self, query):
        """Search X/Twitter for market sentiment and trader commentary."""
        print(f"Searching X/Twitter for: {query}")
        
        # Use Nitter (Twitter frontend) or direct search
        page = self._search(f"https://x.com/search?q={query.replace(' ', '%20')}&f=live", wait=5)
        
        results = []
        tweets = page.query_selector_all("article")
        
        for tweet in tweets[:15]:
            try:
                text = tweet.inner_text()
                if text.strip():
                    results.append(text.strip()[:300])
            except:
                continue
        
        print(f"  Found {len(results)} tweets")
        return results
    
    def check_youtube(self, query):
        """Search YouTube for market analysis videos."""
        print(f"Searching YouTube for: {query}")
        
        page = self._search(f"https://www.youtube.com/results?search_query={query.replace(' ', '+')}", wait=4)
        
        results = []
        videos = page.query_selector_all("ytd-video-renderer")
        
        for video in videos[:10]:
            try:
                title_el = video.query_selector("#video-title")
                meta_el = video.query_selector("#metadata-line")
                
                title = title_el.inner_text().strip() if title_el else ""
                meta = meta_el.inner_text().strip() if meta_el else ""
                href = title_el.get_attribute("href") if title_el else ""
                
                if title:
                    results.append({
                        "title": title,
                        "meta": meta,
                        "url": f"https://youtube.com{href}" if href else ""
                    })
            except:
                continue
        
        print(f"  Found {len(results)} videos")
        return results
    
    def check_forexfactory(self, date_str=None):
        """Check ForexFactory for economic events on a specific date."""
        print(f"Checking ForexFactory events...")
        
        page = self._search("https://www.forexfactory.com/calendar?week=this", wait=4)
        
        events = []
        rows = page.query_selector_all("tr.calendar__row")
        current_date = ""
        
        for row in rows:
            try:
                date_cell = row.query_selector("td.calendar__date")
                if date_cell and date_cell.inner_text().strip():
                    current_date = date_cell.inner_text().strip()
                
                currency_cell = row.query_selector("td.calendar__currency")
                currency = currency_cell.inner_text().strip() if currency_cell else ""
                
                if currency not in ("EUR", "USD"):
                    continue
                
                impact_cell = row.query_selector("td.calendar__impact")
                red_bulls = impact_cell.query_selector_all("span.icon--ff-impact-red") if impact_cell else []
                impact = len(red_bulls)
                
                if impact < 2:
                    continue
                
                event_cell = row.query_selector("td.calendar__event")
                event_name = event_cell.inner_text().strip() if event_cell else ""
                
                time_cell = row.query_selector("td.calendar__time")
                event_time = time_cell.inner_text().strip() if time_cell else ""
                
                actual_cell = row.query_selector("td.calendar__actual")
                actual = actual_cell.inner_text().strip() if actual_cell else ""
                
                forecast_cell = row.query_selector("td.calendar__forecast")
                forecast = forecast_cell.inner_text().strip() if forecast_cell else ""
                
                events.append({
                    "date": current_date,
                    "time": event_time,
                    "currency": currency,
                    "impact": impact,
                    "event": event_name,
                    "actual": actual,
                    "forecast": forecast,
                    "surprise": self._calc_surprise(actual, forecast)
                })
            except:
                continue
        
        print(f"  Found {len(events)} events")
        return events
    
    def check_news(self, query):
        """Search financial news for market-moving events."""
        print(f"Searching news for: {query}")
        
        # Use Google News
        page = self._search(f"https://news.google.com/search?q={query.replace(' ', '%20')}&hl=en", wait=3)
        
        results = []
        articles = page.query_selector_all("article")
        
        for article in articles[:10]:
            try:
                title_el = article.query_selector("a.JtKRv")
                source_el = article.query_selector("div.vr1PYe")
                time_el = article.query_selector("time")
                
                title = title_el.inner_text().strip() if title_el else ""
                source = source_el.inner_text().strip() if source_el else ""
                pub_time = time_el.get_attribute("datetime") if time_el else ""
                
                if title:
                    results.append({
                        "title": title,
                        "source": source,
                        "time": pub_time
                    })
            except:
                continue
        
        print(f"  Found {len(results)} articles")
        return results
    
    def check_investing_sentiment(self):
        """Check Investing.com trader sentiment for EURUSD."""
        print("Checking EURUSD trader sentiment...")
        
        page = self._search("https://www.investing.com/currencies/eur-usd", wait=4)
        
        sentiment = {}
        
        try:
            # Look for sentiment widget
            buy_el = page.query_selector("[data-test='sentiment-buy']")
            sell_el = page.query_selector("[data-test='sentiment-sell']")
            
            if buy_el:
                sentiment["buy_pct"] = buy_el.inner_text().strip()
            if sell_el:
                sentiment["sell_pct"] = sell_el.inner_text().strip()
            
            # Current price
            price_el = page.query_selector("[data-test='instrument-price-last']")
            if price_el:
                sentiment["price"] = price_el.inner_text().strip()
        except:
            pass
        
        print(f"  Sentiment: {sentiment}")
        return sentiment
    
    # =========================================================
    # COMPOUND RESEARCH METHODS
    # =========================================================
    
    def investigate_date(self, date_str):
        """Full investigation of what happened on a specific date."""
        print(f"\n{'='*60}")
        print(f"DEEP RESEARCH: {date_str}")
        print(f"{'='*60}\n")
        
        results = {}
        
        # 1. Economic events
        results["events"] = self.check_forexfactory(date_str)
        
        # 2. News
        results["news"] = self.check_news(f"EURUSD {date_str}")
        
        # 3. Twitter sentiment
        results["twitter"] = self.check_twitter(f"EURUSD {date_str}")
        
        # 4. YouTube analysis
        results["youtube"] = self.check_youtube(f"EURUSD analysis {date_str}")
        
        # Save
        output_file = OUTPUT_DIR / f"research_{date_str}.json"
        with open(output_file, "w") as f:
            json.dump(results, f, indent=2, default=str)
        
        print(f"\nResearch saved to {output_file}")
        return results
    
    def full_postmortem(self, start_date, end_date):
        """Full post-mortem analysis of a losing period."""
        print(f"\n{'='*60}")
        print(f"POST-MORTEM ANALYSIS: {start_date} to {end_date}")
        print(f"{'='*60}\n")
        
        report = []
        report.append(f"# DESTROYER QUANTUM — Post-Mortem Report")
        report.append(f"## Period: {start_date} to {end_date}")
        report.append(f"## Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
        report.append("")
        
        # 1. Economic calendar
        events = self.check_forexfactory()
        report.append("## Economic Events")
        if events:
            for e in events:
                surprise = " ⚠️ SURPRISE" if e.get("surprise") else ""
                report.append(f"- [{e['date']}] {e['currency']} {e['event']} (Impact: {'🔴'*e['impact']}){surprise}")
                if e.get('actual') and e.get('forecast'):
                    report.append(f"  Actual: {e['actual']} vs Forecast: {e['forecast']}")
        else:
            report.append("- No high-impact events found")
        report.append("")
        
        # 2. News search
        news = self.check_news(f"EURUSD {start_date} to {end_date}")
        report.append("## News Headlines")
        for n in news:
            report.append(f"- [{n.get('source', 'Unknown')}] {n['title']}")
        report.append("")
        
        # 3. Twitter sentiment
        tweets = self.check_twitter(f"EURUSD {start_date}")
        report.append("## Trader Sentiment (Twitter)")
        for t in tweets[:5]:
            report.append(f"- {t[:200]}")
        report.append("")
        
        # 4. YouTube analysis
        videos = self.check_youtube(f"EURUSD analysis {start_date}")
        report.append("## YouTube Analysis Videos")
        for v in videos[:5]:
            report.append(f"- {v['title']} ({v.get('meta', '')})")
            if v.get('url'):
                report.append(f"  {v['url']}")
        report.append("")
        
        # Save report
        report_text = "\n".join(report)
        report_file = OUTPUT_DIR / f"postmortem_{start_date}_{end_date}.md"
        with open(report_file, "w") as f:
            f.write(report_text)
        
        print(f"\nPost-mortem saved to {report_file}")
        print(report_text)
        
        return report_text
    
    def research_topic(self, topic):
        """Research a specific trading topic across multiple sources."""
        print(f"\nResearching: {topic}\n")
        
        results = {}
        results["news"] = self.check_news(topic)
        results["twitter"] = self.check_twitter(topic)
        results["youtube"] = self.check_youtube(topic)
        
        # Save
        safe_topic = topic.replace(" ", "_")[:50]
        output_file = OUTPUT_DIR / f"research_{safe_topic}.json"
        with open(output_file, "w") as f:
            json.dump(results, f, indent=2, default=str)
        
        return results
    
    # =========================================================
    # HELPERS
    # =========================================================
    
    def _calc_surprise(self, actual, forecast):
        """Check if actual deviated significantly from forecast."""
        if not actual or not forecast:
            return False
        try:
            a = float(actual.replace("%", "").replace(",", "").strip())
            f = float(forecast.replace("%", "").replace(",", "").strip())
            if f == 0:
                return False
            deviation = abs((a - f) / f) * 100
            return deviation > 20  # 20%+ deviation = surprise
        except:
            return False
    
    def close(self):
        """Close the browser."""
        try:
            self.browser.close()
        except:
            pass
    
    def __del__(self):
        self.close()


# =========================================================
# CLI INTERFACE
# =========================================================

def main():
    """CLI: python3 deep_research.py <command> <args>"""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 deep_research.py date 2025-01-15          # Investigate a date")
        print("  python3 deep_research.py topic 'EURUSD crash'     # Research a topic")
        print("  python3 deep_research.py postmortem 2025-01-10 2025-01-15  # Full post-mortem")
        print("  python3 deep_research.py sentiment                # Current EURUSD sentiment")
        return
    
    r = DeepResearch()
    
    command = sys.argv[1]
    
    try:
        if command == "date" and len(sys.argv) > 2:
            r.investigate_date(sys.argv[2])
        elif command == "topic" and len(sys.argv) > 2:
            r.research_topic(sys.argv[2])
        elif command == "postmortem" and len(sys.argv) > 3:
            r.full_postmortem(sys.argv[2], sys.argv[3])
        elif command == "sentiment":
            r.check_investing_sentiment()
        else:
            print(f"Unknown command: {command}")
    finally:
        r.close()


if __name__ == "__main__":
    main()
