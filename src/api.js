dimmer = $('.ui.dimmer');

// if page has just loaded and we have URL params, then reset local storage
// set dropdowns based on values in localStorage
// when dropdown changes, reset URL and reset localstorage

/*
corona = {
  region: null,
  subregion: null,
  country: null,
  state: null,
  city: null
};

window.history.pushState(null, '', '/page2.php');

window.localstorage.corona = {};
*/

function loadPage() {
  $('#region').dropdown({ onChange: selectRegion });
  $('#subregion').dropdown({ onChange: selectSubregion });
  $('#country').dropdown({ onChange: selectCountry });
  $('#state').dropdown({ onChange: selectState });
  $('#city').dropdown({ onChange: selectCity });
  // get params from URL
  // if any exist, then reset local storage
  loadRegions("https://corona.kranzky.com/api.json");
}

function loadRegions(uri) {
  $('#region').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#region .menu').empty();
      if (!_.isEmpty(response.data.regions)) {    
        _.each(response.data.regions, function(value) {
          $('#region .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#region').show();
      }
      // load subregion if region selected in local storage
      refreshDisplay(uri, response.data, response.request.responseText);
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadSubregions(uri) {
  $('#subregion').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#subregion .menu').empty();
      if (!_.isEmpty(response.data.subregions)) {    
        _.each(response.data.subregions, function(value) {
          $('#subregion .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#subregion').show();
      }
      // load country if subregion selected in local storage
      refreshDisplay(uri, response.data, response.request.responseText);
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadCountries(uri) {
  $('#country').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#country .menu').empty();
      if (!_.isEmpty(response.data.countries)) {    
        _.each(response.data.countries, function(value) {
          $('#country .menu').append(`<div class="item" data-value="${value.uri}"><i class="${value.id.toLowerCase()} flag"></i>${value.name}</div>`);
        });
        $('#country').show();
      }
      // load country if subregion selected in local storage
      refreshDisplay(uri, response.data, response.request.responseText);
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadStates(uri) {
  $('#state').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#state .menu').empty();
      if (!_.isEmpty(response.data.states)) {    
        _.each(response.data.states, function(value) {
          $('#state .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#state').show();
      }
      // load state if country selected in local storage
      refreshDisplay(uri, response.data, response.request.responseText);
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadCities(uri) {
  $('#city').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#city .menu').empty();
      if (!_.isEmpty(response.data.cities)) {    
        _.each(response.data.cities, function(value) {
          $('#city .menu').append(`<div class="item" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#city').show();
      }
      // load city if country selected in local storage
      refreshDisplay(uri, response.data, response.request.responseText);
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function loadResults(uri) {
  axios.get(uri)
    .then(function (response) {
      refreshDisplay(uri, response.data, response.request.responseText);
      dimmer.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      dimmer.removeClass('active');
    });
}

function selectRegion(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#subregion').hide();
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  // set url and local storage if this has been selected manually
  loadSubregions(uri);
}

function selectSubregion(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  // set url and local storage if this has been selected manually
  loadCountries(uri);
}

function selectCountry(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#state').hide();
  $('#city').hide();
  // set url and local storage if this has been selected manually
  loadStates(uri);
}

function selectState(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#city').hide();
  // set url and local storage if this has been selected manually
  loadCities(uri);
}

function selectCity(uri) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  // set url and local storage if this has been selected manually
  loadResults(uri);
}
