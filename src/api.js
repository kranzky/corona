loading = $('.ui.dimmer');

function loadState() {
  blob = sessionStorage.getItem('corona');
  if (_.isNull(blob)) {
    arguments = _.compact(_.split(window.location.href.replace(/^[^?]*[?]*/, ''), '&'))
    arguments = _.fromPairs(_.map(arguments, function(v) { return _.split(v, '=') }))
    window.corona = _.pick(arguments, ['region', 'subregion', 'country', 'state', 'city'])
  } else {
    window.corona = JSON.parse(blob);
  }
}

function saveState() {
  sessionStorage.setItem('corona', JSON.stringify(window.corona));
  url = window.location.href.replace(/[?].*/, '');
  arguments = _.map(_.toPairs(window.corona), function(pair) { return pair.join('=') }).join("&");
  if (!_.isEmpty(arguments)) {
    url += `?${arguments}`;
  }
  if (url != window.location.href) {
    history.replaceState(null, null, url);
  }
}

function loadPage() {
  $('#region').dropdown({ onChange: selectRegion, clearable: true });
  $('#subregion').dropdown({ onChange: selectSubregion, clearable: true });
  $('#country').dropdown({ onChange: selectCountry, clearable: true });
  $('#state').dropdown({ onChange: selectState, clearable: true });
  $('#city').dropdown({ onChange: selectCity, clearable: true });
  loadState();
  saveState();
  loadRegions("https://corona.kranzky.com/api.json");
}

// TODO: dry this up
function loadRegions(uri) {
  loading.addClass('active');
  console.log('load');
  $('#region').dropdown('restore defaults');
  selected_uri = null;
  axios.get(uri)
    .then(function (response) {
      $('#region .menu').empty();
      if (!_.isEmpty(response.data.regions)) {    
        _.forIn(response.data.regions, function(value, key) {
          if (window.corona.region == key) {
            selected_uri = value.uri;
          }
          $('#region .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#region').show();
      }
      if (_.isNull(selected_uri)) {
        console.log('clear state');
        delete window.corona.region;
        delete window.corona.subregion;
        delete window.corona.country;
        delete window.corona.state;
        delete window.corona.city;
        saveState();
        refreshDisplay(uri, response.data, response.request.responseText);
      } else {
        setTimeout(function() { $('#region').dropdown('set selected', selected_uri) });
      }
      loading.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      loading.removeClass('active');
    });
}

function loadSubregions(uri) {
  $('#subregion').dropdown('restore defaults');
  selected_uri = null;
  axios.get(uri)
    .then(function (response) {
      $('#subregion .menu').empty();
      if (!_.isEmpty(response.data.subregions)) {    
        _.forIn(response.data.subregions, function(value, key) {
          if (window.corona.subregion == key) {
            // make region selected
            selected_uri = value.uri;
          }
          $('#subregion .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#subregion').show();
      }
      if (_.isNull(selected_uri)) {
        delete window.corona.subregion;
        delete window.corona.country;
        delete window.corona.state;
        delete window.corona.city;
        saveState();
        refreshDisplay(uri, response.data, response.request.responseText);
      } else {
        loadCountries(selected_uri);
      }
      loading.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      loading.removeClass('active');
    });
}

function loadCountries(uri) {
  $('#country').dropdown('restore defaults');
  selected_uri = null;
  axios.get(uri)
    .then(function (response) {
      $('#country .menu').empty();
      if (!_.isEmpty(response.data.countries)) {    
        _.forIn(response.data.countries, function(value, key) {
          if (window.corona.country == key) {
            // make region selected
            selected_uri = value.uri;
          }
          $('#country .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}"><i class="${value.id.toLowerCase()} flag"></i>${value.name}</div>`);
        });
        $('#country').show();
      }
      if (_.isNull(selected_uri)) {
        delete window.corona.country;
        delete window.corona.state;
        delete window.corona.city;
        saveState();
        refreshDisplay(uri, response.data, response.request.responseText);
      } else {
        loadStates(selected_uri);
      }
      loading.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      loading.removeClass('active');
    });
}

function loadStates(uri) {
  $('#state').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#state .menu').empty();
      if (!_.isEmpty(response.data.states)) {    
        _.forIn(response.data.states, function(value, key) {
          $('#state .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#state').show();
      }
      // load state if country selected in local storage
      refreshDisplay(uri, response.data, response.request.responseText);
      loading.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      loading.removeClass('active');
    });
}

function loadCities(uri) {
  $('#city').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#city .menu').empty();
      if (!_.isEmpty(response.data.cities)) {    
        _.forIn(response.data.cities, function(value, key) {
          $('#city .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
        });
        $('#city').show();
      }
      // load city if country selected in local storage
      refreshDisplay(uri, response.data, response.request.responseText);
      loading.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      loading.removeClass('active');
    });
}

function loadResults(uri) {
  axios.get(uri)
    .then(function (response) {
      refreshDisplay(uri, response.data, response.request.responseText);
      loading.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      loading.removeClass('active');
    });
}

// TODO: dry this up
function selectRegion(uri, name, item) {
  console.log('select');
  if (loading.hasClass('active')) {
    return;
  }
  $('#subregion').hide();
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  delete window.corona['region'];
  delete window.corona['subregion'];
  delete window.corona['country'];
  delete window.corona['state'];
  delete window.corona['city'];
  if (!_.isEmpty(uri)) {
    window.corona['region'] = item[0].dataset.id;
    saveState();
    loadSubregions(uri);
  } else {
    saveState();
    loadRegions("https://corona.kranzky.com/api.json");
  }
}

function selectSubregion(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  loading.addClass('active');
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  window.corona.subregion = item[0].dataset.id;
  delete window.corona.country;
  delete window.corona.state;
  delete window.corona.city;
  saveState();
  loadCountries(uri);
}

function selectCountry(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  loading.addClass('active');
  $('#state').hide();
  $('#city').hide();
  window.corona.country = item[0].dataset.id;
  delete window.corona.state;
  delete window.corona.city;
  saveState();
  loadStates(uri);
}

function selectState(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  loading.addClass('active');
  $('#city').hide();
  window.corona.state = item[0].dataset.id;
  delete window.corona.city;
  saveState();
  loadCities(uri);
}

function selectCity(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  loading.addClass('active');
  window.corona.city = item[0].dataset.id;
  saveState();
  loadResults(uri);
}
