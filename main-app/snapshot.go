package dropp

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	gq "github.com/PuerkitoBio/goquery"
)

// Snapshot contains a snapshot of the current status of an item.
type Snapshot struct {
	Availability string
	OnEbay       bool
	Price        float64
	CreatedAt    time.Time
}

// SnapshotDiff Is created if there is a difference between the current and the
// previous snaphot.
type SnapshotDiff struct {
	ItemName       string
	ItemURL        string
	PreviousAva    string
	PreviousStatus bool
	PreviousPrice  float64
	CurrentAva     string
	CurrentStatus  bool
	CurrentPrice   float64
}

// EbayPrice contains the price and currency as fetched from the Ebay service
type EbayPrice struct {
	CurrencyID string `json:"_currencyID"`
	Value      string `json:"value"`
}

// EbayItem is the full item generated by the Ebay service
type EbayItem struct {
	CurrentPrice EbayPrice `json:"current_price"`
	ID           string    `json:"id"`
	ItemName     string    `json:"name"`
	StockCount   string    `json:"quantity"`
	SoldCount    string    `json:"quantity_sold"`
	Status       string    `json:"status"`
	ItemPageURL  string    `json:"url"`
}

// BGData is a partial representation ot the data JSON for a BG item
type BGData struct {
	Message string  `json:"message"`
	Price   float64 `json:"final_price"`
}

func (snap *Snapshot) getBGAva(response *http.Response) {
	// Scrape the page and get availability
	log.Print("Scraping BG page to retrieve availability")
	doc, err := gq.NewDocumentFromResponse(response)
	if err != nil {
		panic(err.Error())
	}
	ava := doc.Find(".status").Text()
	snap.Availability = ava
	return
}
func (snap *Snapshot) getSourceData(response *http.Response) {
	data := BGData{}
	err := json.NewDecoder(response.Body).Decode(&data)
	if err != nil {
		log.Printf("Error while decoding BG data for item %s: %s", response.Request.URL, err)
		return
	}
	snap.Availability = data.Message
	snap.Price = data.Price
}

func (snap *Snapshot) getEbayStatus(response *http.Response) {
	ebayItem := EbayItem{}

	err := json.NewDecoder(response.Body).Decode(&ebayItem)
	if err != nil {
		log.Printf("Error while converting the Ebay JSON %s", err)
		return
	}

	log.Printf("The status of item %s is %s", ebayItem.ID, ebayItem.Status)

	if ebayItem.Status == "Active" {
		snap.OnEbay = true
	} else {
		snap.OnEbay = false
	}
}
