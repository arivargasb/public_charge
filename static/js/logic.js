var myMap = L.map("map", {
  // center: [37.8, -96],
  center:[36.778259, -119.417931],
  zoom: 6
});

L.tileLayer("https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}", {
  attribution: "Map data &copy; <a href='https://www.openstreetmap.org/'>OpenStreetMap</a> contributors, <a href='https://creativecommons.org/licenses/by-sa/2.0/'>CC-BY-SA</a>, Imagery © <a href='https://www.mapbox.com/'>Mapbox</a>",
  maxZoom: 18,
  id: "mapbox.streets",
  accessToken: "pk.eyJ1IjoiYXJpdmFyZ2FzYiIsImEiOiJjazByYm16ajIwNG1kM25zN2M4dDRmNGQyIn0.Ya-5ppfCOpgBtfNonUAhCQ"
}).addTo(myMap);

var change = ""

function getColor(change) {
      return change < -20  ? '#BD0026' :
      change < -10  ? '#E31A1C' :       
      change < -5  ? '#FC4E2A' :
      change < -2.5  ? '#FD8D3C':
      change < -2  ? '#FEB24C' :
      change < -1   ? '#FED976' :
      change < 0    ?  '#FED976':	 
      change >= 0   ? '#cff7cf' :
       'white';   
                       
} 

var json = "data/clean/SNAP_county_clean_CA.json";
var geojson = "data/geojson/gz_2010_us_050_00_500k.json";

var array = [];

d3.json(json, function(data) {

var changes=data;

for (var i = 0; i < changes.length; i++) {
  if (changes[i].semester=="0119") {
  array.push({
    "county": changes[i].county_id,
    "state": changes[i].state_id,
    "county_name": changes[i].county_name,
    "state_name": changes[i].state_name,
    "color": getColor(changes[i].snap_biannual_chan),
    "change": changes[i].snap_biannual_chan,
    "semester": "Sem1 2017"
  });
  
};
};
});
console.log(array)


  d3.json(geojson, function(data1) {
      var geodata=data1.features;
  // Loop within the array
      for (var i = 0; i < array.length; i++) {
  // Loop within each element of the array
        for (var j = 0; j < geodata.length; j++) {
            if (array[i].county == geodata[j].properties.COUNTY
             && array[i].state == geodata[j].properties.STATE) {
            
              // Creating a geoJSON layer with the retrieved data
              L.geoJson(geodata[j], {
                // Style each feature (in this case a neighborhood)
                style: function(feature) {
                  return {
                    color: array[i].color,
                    fillColor: array[i].color,
                    fillOpacity: 0.5,
                    weight: 1.5
                  };
                  // console.log(array[i].color);
                }
                }).addTo(myMap);
              };
        
      };
      };
  });
  


