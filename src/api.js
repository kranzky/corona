function loadPage() {
  $('#region').dropdown({ onChange: selectRegion });
  $('#subregion').dropdown({ onChange: selectSubregion });
  $('#country').dropdown({ onChange: selectCountry });
  $('#state').dropdown({ onChange: selectState });
  loadRegions("https://corona.kranzky.com/index.json");
}

function refreshDisplay(data) {
  console.debug(data);
}

function loadRegions(uri) {
  $('#region').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#region .menu').empty();
      refreshDisplay(response.data);
      if (!_.isEmpty(response.data.regions)) {    
        _.each(response.data.regions, function(value) {
          $('#region .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#region').show();
      }
    })
    .catch(function (error) {
      console.log(error);
    });
}

function loadSubregions(uri) {
  $('#subregion').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#subregion .menu').empty();
      refreshDisplay(response.data);
      if (!_.isEmpty(response.data.subregions)) {    
        _.each(response.data.subregions, function(value) {
          $('#subregion .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#subregion').show();
      }
    })
    .catch(function (error) {
      console.log(error);
    });
}

function loadCountries(uri) {
  $('#country').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#country .menu').empty();
      refreshDisplay(response.data);
      if (!_.isEmpty(response.data.countries)) {    
        _.each(response.data.countries, function(value) {
          $('#country .menu').append(`<div class="item" data-value="${value.uri}">${value.flag} ${value.name}</div>`);
        });
        $('#country').show();
      }
    })
    .catch(function (error) {
      console.log(error);
    });
}

function loadStates(uri) {
  $('#state').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#state .menu').empty();
      refreshDisplay(response.data);
      if (!_.isEmpty(response.data.states)) {    
        _.each(response.data.states, function(value) {
          $('#state .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#state').show();
      }
    })
    .catch(function (error) {
      console.log(error);
    });
}

function loadResults(uri) {
  axios.get(uri)
    .then(function (response) {
      refreshDisplay(response);
    })
    .catch(function (error) {
      console.log(error);
    });
}

function selectRegion(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  $('#subregion').hide();
  $('#country').hide();
  $('#state').hide();
  loadSubregions(uri);
}

function selectSubregion(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  $('#country').hide();
  $('#state').hide();
  loadCountries(uri);
}

function selectCountry(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  $('#state').hide();
  loadStates(uri);
}

function selectState(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  loadResults(uri);
}
