dimmer = $('.ui.dimmer');

function getArgs() {
  blob = sessionStorage.getItem('corona');
  if (_.isNull(blob)) {
    arguments = _.compact(_.split(window.location.href.replace(/^[^?]*[?]*/, ''), '&'))
    arguments = _.fromPairs(_.map(arguments, function(v) { return _.split(v, '=') }))
    window.corona = _.pick(arguments, ['region', 'subregion', 'country', 'state', 'city'])
  } else {
    window.corona = JSON.parse(blob);
  }
  setArgs();
}

function setArgs() {
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
  $('#region').dropdown({ onChange: selectRegion });
  $('#subregion').dropdown({ onChange: selectSubregion });
  $('#country').dropdown({ onChange: selectCountry });
  $('#state').dropdown({ onChange: selectState });
  $('#city').dropdown({ onChange: selectCity });
  getArgs()
  loadRegions("https://corona.kranzky.com/api.json");
}

function loadRegions(uri) {
  $('#region').dropdown('restore defaults');
  axios.get(uri)
    .then(function (response) {
      $('#region .menu').empty();
      if (!_.isEmpty(response.data.regions)) {    
        _.forIn(response.data.regions, function(value, key) {
          $('#region .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
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
        _.forIn(response.data.subregions, function(value, key) {
          $('#subregion .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
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
        _.forIn(response.data.countries, function(value, key) {
          $('#country .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}"><i class="${value.id.toLowerCase()} flag"></i>${value.name}</div>`);
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
        _.forIn(response.data.states, function(value, key) {
          $('#state .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
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
        _.forIn(response.data.cities, function(value, key) {
          $('#city .menu').append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
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

function selectRegion(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#subregion').hide();
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  window.corona.region = item[0].dataset.id;
  setArgs();
  loadSubregions(uri);
}

function selectSubregion(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#country').hide();
  $('#state').hide();
  $('#city').hide();
  window.corona.subregion = item[0].dataset.id;
  setArgs();
  loadCountries(uri);
}

function selectCountry(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#state').hide();
  $('#city').hide();
  window.corona.country = item[0].dataset.id;
  setArgs();
  loadStates(uri);
}

function selectState(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  $('#city').hide();
  window.corona.state = item[0].dataset.id;
  setArgs();
  loadCities(uri);
}

function selectCity(uri, name, item) {
  if (_.isEmpty(uri)) {
    return;
  }
  dimmer.addClass('active');
  window.corona.city = item[0].dataset.id;
  setArgs();
  loadResults(uri);
}
