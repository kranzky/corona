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
  window.corona.startup = true;
  loadRegions("https://corona.kranzky.com/api.json");
}

function getPlural(target) {
  return { region: 'regions', subregion: 'subregions', country: 'countries', state: 'states', city: 'cities' }[target]
}

function load(target, uri) {
  loading.addClass('active');
  $(`#${target}`).dropdown('restore defaults');
  selected_uri = null;
  index = getPlural(target);
  axios.get(uri)
    .then(function (response) {
      $(`#${target} .menu`).empty();
      if (!_.isEmpty(response.data[index])) {    
        _.forIn(response.data[index], function(value, key) {
          if (window.corona[target] == key) {
            selected_uri = value.uri;
          }
          $(`#${target} .menu`).append(`<div class="item" data-id="${key}" data-value="${value.uri}">${value.name}</div>`);
        });
        $(`#${target}`).show();
      }
      if (_.isNull(selected_uri)) {
        delete window.corona['startup']
        hide = false;
        _.each(['region', 'subregion', 'country', 'state', 'city'], function(item) {
          if (item == target) {
            hide = true;
          }
          if (hide) {
            delete window.corona[item];
          }
        });
        saveState();
        refreshDisplay(uri, response.data, response.request.responseText);
      } else {
        setTimeout(function() { $(`#${target}`).dropdown('set selected', selected_uri) });
      }
      loading.removeClass('active');
    })
    .catch(function (error) {
      console.log(error);
      loading.removeClass('active');
    });
}
function loadRegions(uri) {
  load('region', uri);
}
function loadSubregions(uri) {
  load('subregion', uri);
}
function loadCountries(uri) {
  load('country', uri);
}
function loadStates(uri) {
  load('state', uri);
}
function loadCities(uri) {
  load('city', uri);
}

function loadResults(uri) {
  loading.addClass('active');
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

function select(target, child, uri, item, child_uri) {
  if (loading.hasClass('active')) {
    return;
  }
  if (window.corona.startup !== true) {
    hide = false;
    _.each(['region', 'subregion', 'country', 'state', 'city'], function(item) {
      if (item == child) {
        hide = true;
      }
      if (hide) {
        $(`#${item}`).hide();
        delete window.corona[item];
      }
    });
  }
  if (!_.isEmpty(uri)) {
    window.corona[target] = item[0].dataset.id;
    saveState();
    if (_.isNull(child)) {
      loadResults(uri);
    } else {
      load(child, uri);
    }
  } else {
    delete window.corona[target];
    saveState();
    load(target, child_uri);
  }
}

function selectRegion(uri, name, item) {
  select('region', 'subregion', uri, item, "https://corona.kranzky.com/api.json");
}
function selectSubregion(uri, name, item) {
  select('subregion', 'country', uri, item, $("#region").dropdown('get value'));
}
function selectCountry(uri, name, item) {
  select('country', 'state', uri, item, $("#subregion").dropdown('get value'));
}
function selectState(uri, name, item) {
  select('state', 'city', uri, item, $("#country").dropdown('get value'));
}
function selectCity(uri, name, item) {
  select('city', null, uri, item, $("#state").dropdown('get value'));
}
