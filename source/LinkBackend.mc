using Toybox.Communications as Comm;
using Toybox.Application.Storage as Stor;
using Toybox.Time;
using Toybox.Lang;

(:background)
class LinkBackend {
    const CACHETIME = 10;
    const CACHEVALUEKEY = "price";
    const PRICECACHEVALUEKEY = "price_cache_time";
    const SECONDSINDAY = 86400;
    
    enum {
        CoinGecko,
        CoinMarketCap,
        Coinbase,
        Bitstamp,
        Kraken
    }
    
    enum {
        USD,
        EUR,
        CNY,
        GBP,
        CAD,
        ZAR,
        PLN,
        AUD,
        HKD,
        NOK
    }
    
    enum {
        mmddyyyy,
        ddmmyyyy
    }
    
    enum {
        hr12,
        hr24
    }
    
    const BACKENDS = [
        "CoinGecko",
        "CoinMarketCap",
        "Coinbase",
        "Bitstamp",
        "Kraken"
    ];
    
    const CURRENCIES = [
        "USD",
        "EUR",
        "CNY",
        "GBP",
        "CAD",
        "ZAR",
        "PLN",
        "AUD",
        "HKD",
        "NOK"
    ];
    
    const DATEFORMATS = [
        "mmddyyyy",
        "ddmmyyyy"
    ];
    
    const TIMEFORMATS = [
        "12hr",
        "24hr"
    ];
    
    const CURRENCYSYMBOLS = {
        "USD" => "$",
        "EUR" => "€",
        "CNY" => "¥",
        "GBP" => "£",
        "CAD" => "$",
        "ZAR" => "R",
        "PLN" => "zł",
        "AUD" => "$",
        "HKD" => "$",
        "NOK" => "kr"
    };
    
    hidden var crypto;
    hidden var currency;
    hidden var backend;
    var apikey;
    hidden var dateformat;
    hidden var timeformat;
    
    var fetching = false;
    var fetch;
    var fetchFailed = false;
    var price = "";
    var myOnReceive;
    
    function initialize(cryptoVal) {
        crypto = cryptoVal;
        var storedPrice = Stor.getValue(CACHEVALUEKEY);
        if (storedPrice) {
            price = storedPrice;
        }
    }
    
    function makeRequest(onReceiveCallback) {
        if (!System.getDeviceSettings().phoneConnected) {
            System.println("No Connection");
            return;
        }
        if (apiKeyNeeded()) {
            System.println("API Key Required");
            return;
        }
        var url = getBackendURL();
        System.println(url);
        var params = {};
        var options = {
            :method => Comm.HTTP_REQUEST_METHOD_GET,
            :headers => {"Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON},
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        
        if (backend.equals(BACKENDS[CoinMarketCap])) {
            options[:headers]["X-CMC_PRO_API_KEY"] = apikey;
        }
        
        Comm.makeWebRequest(url, params, options, method(:onReceive));
        fetching = true;
        fetchFailed = false;
        myOnReceive = onReceiveCallback;
    }
    
    function getBackendURL() {
        if (backend.equals(BACKENDS[CoinGecko])) {
            return "https://api.coingecko.com/api/v3/simple/price?ids=chainlink&vs_currencies=" + currency.toLower();
        }
        if (backend.equals(BACKENDS[CoinMarketCap])) {
            return "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=LINK&convert=" + currency;
        }
        if (backend.equals(BACKENDS[Coinbase])) {
            return "https://api.coinbase.com/v2/prices/LINK-" + currency + "/spot";
        }
        if (backend.equals(BACKENDS[Bitstamp])) {
            return "https://www.bitstamp.net/api/v2/ticker/link" + currency.toLower();
        }
        if (backend.equals(BACKENDS[Kraken])) {
            return "https://api.kraken.com/0/public/Ticker?pair=LINK" + currency;
        }
        return "";
    }
    
    function getPrice(data) {
        if (backend.equals(BACKENDS[CoinGecko])) {
            return data["chainlink"][currency.toLower()];
        }
        if (backend.equals(BACKENDS[CoinMarketCap])) {
            return data["data"]["LINK"]["quote"][currency]["price"];
        }
        if (backend.equals(BACKENDS[Coinbase])) {
            return data["data"]["amount"];
        }
        if (backend.equals(BACKENDS[Bitstamp])) {
            return data["last"];
        }
        if (backend.equals(BACKENDS[Kraken])) {
            var pair = "XLINK" + "Z" + currency;
            return data["result"][pair]["c"][0];
        }
        return null;
    }
    
    function onReceive(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String) as Void {
        fetching = false;
        System.println(data);
        if (responseCode == 200) {
            System.println("Request Successful: " + data);
            price = getPrice(data);
            price = formatPrice(price);
            
            Stor.setValue(CACHEVALUEKEY, price);
            Stor.setValue(PRICECACHEVALUEKEY, Time.now().value());
            
            myOnReceive.invoke();
            
        } else {
            System.println("Response: " + responseCode);
            fetchFailed = true;
        }
    }
    
    // Rest of utility functions remain the same
    function getDateformat() { return dateformat; }
    function setDateformat(aDateformat) { dateformat = aDateformat; }
    function getTimeformat() { return timeformat; }
    function setTimeformat(aTimeformat) { timeformat = aTimeformat; }
    function apiKeyNeeded() { return backend.equals(BACKENDS[CoinMarketCap]) && apikey.length() < 30; }
    function getCurrency() { return currency; }
    function setCurrency(aCurrency) { currency = aCurrency; }
    function getBackend() { return backend; }
    function setBackend(aBackend) { backend = aBackend; }
    function getCurrencySymbol() { return CURRENCYSYMBOLS[currency]; }
    
    function formatPrice(price) {
        var remainder = price - price.toNumber();
        if (remainder != 0) {
            return price.toString().toFloat().format("%.2f");
        } else {
            return price.toString().toFloat().format("%.0f");
        }
    }
    
    function cacheExpired() {
        var cacheTime = Stor.getValue(PRICECACHEVALUEKEY);
        var nowTime = 0;
        var timeDiff = 10000;
        if (cacheTime) {
            nowTime = Time.now().value();
            timeDiff = nowTime - cacheTime;
        }
        return timeDiff > CACHETIME;
    }
    
    function getPriceTime() {
        var priceTimeValue = Stor.getValue(PRICECACHEVALUEKEY);
        var priceMoment = new Time.Moment(Time.now().value());
        if (priceTimeValue) {
            priceMoment = new Time.Moment(priceTimeValue);
        }
        return Time.Gregorian.info(priceMoment, Time.FORMAT_SHORT);
    }
    
    function getFormattedPriceTime() {
        var priceTime = getPriceTime();
        if (timeformat.equals(TIMEFORMATS[hr24])) {
            return priceTime.hour.format("%2d") + ":" + priceTime.min.format("%02d");
        } else {
            var hour = priceTime.hour % 12;
            var formattedHour;
            if (hour < 10) {
                if (hour == 0) { hour = 12; }
                formattedHour = hour.format("%1d");
            } else {
                if (hour == 0) { hour = 12; }
                formattedHour = hour.format("%2d");
            }
            var amPM = priceTime.hour < 12 ? "AM" : "PM";
            return formattedHour + ":" + priceTime.min.format("%02d") + amPM;
        }
    }
    
    function getFormattedPriceDate() {
        var priceTime = getPriceTime();
        var day = priceTime.day;
        var month = priceTime.month;
        var year = priceTime.year;
        
        if (dateformat.equals(DATEFORMATS[ddmmyyyy])) {
            return day.format("%1d") + "/" + month.format("%1d") + "/" + year.format("%4d");
        } else {
            return month.format("%1d") + "/" + day.format("%1d") + "/" + year.format("%4d");
        }
    }
    
    function cacheOlderThanADayOld() {
        var cacheTime = Stor.getValue(PRICECACHEVALUEKEY);
        var nowTime = 0;
        var timeDiff = 10000;
        if (cacheTime) {
            nowTime = Time.now().value();
            timeDiff = nowTime - cacheTime;
        }
        return timeDiff > SECONDSINDAY;
    }
    
    function getFormattedPriceDateOrTime() {
        if (cacheOlderThanADayOld()) {
            return getFormattedPriceDate();
        } else {
            return getFormattedPriceTime();
        }
    }
}