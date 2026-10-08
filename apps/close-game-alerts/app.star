def _endpoint(sport):
    if sport == "NFL":
        return "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"

    if sport == "NCAA FOOTBALL":
        return "https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard"

    if sport == "NCAA BASKETBALL":
        return "https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard"

    if sport == "NBA":
        return "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard"

    if sport == "NHL":
        return "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard"

    if sport == "MLB":
        return "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard"

    return ""


def _sports_from_input(value):
    text = str(value).strip()

    if text == "":
        return []

    text = text.replace("[", "").replace("]", "")

    result = []

    for item in text.split(","):
        item = item.strip().strip("'").strip('"')

        if item != "":
            result.append(item)

    if len(result) == 1 and result[0] == "ALL SPORTS":
        return [
            "NFL",
            "NCAA FOOTBALL",
            "NCAA BASKETBALL",
            "NBA",
            "NHL",
            "MLB"
        ]

    return result


def _selection(value):
    return _sports_from_input(value)


def _normalize(value):
    text = str(value).upper()
    text = text.replace("&", "AND")
    text = text.replace(".", "")
    text = text.replace("'", "")
    text = text.replace("-", " ")
    text = text.replace("/", " ")

    return " ".join(text.split())


def _team_key(sport):
    if sport == "NFL":
        return "nfl_teams"
    if sport == "NCAA FOOTBALL":
        return "ncaa_football_teams"
    if sport == "NCAA BASKETBALL":
        return "ncaa_basketball_teams"
    if sport == "NBA":
        return "nba_teams"
    if sport == "NHL":
        return "nhl_teams"
    if sport == "MLB":
        return "mlb_teams"
    return ""

def _team_selected(ctx, sport, team):
    mode = str(ctx.inputs["team_mode"]).strip().upper()
    if mode == "ALL TEAMS":
        return True

    key = _team_key(sport)
    if key == "":
        return True

    selected = _selection(ctx.inputs[key])

    if len(selected) == 0:
        sport_input = str(ctx.inputs["sport"]).strip().upper()

        if sport_input == "ALL SPORTS":
            keys = [
                "nfl_teams",
                "ncaa_football_teams",
                "ncaa_basketball_teams",
                "nba_teams",
                "nhl_teams",
                "mlb_teams"
            ]

            any_selected = False
            for other_key in keys:
                if len(_selection(ctx.inputs[other_key])) > 0:
                    any_selected = True
                    break

            if any_selected:
                return False

        return True

    values = [
        team.get("displayName", ""),
        team.get("location", ""),
        team.get("shortDisplayName", ""),
        team.get("name", ""),
        team.get("abbreviation", "")
    ]

    normalized_values = []
    for value in values:
        normalized_values.append(_normalize(value))

    for choice in selected:
        wanted = _normalize(str(choice))

        for value in normalized_values:
            if wanted == value:
                return True

    return False

def _clock_seconds(clock):
    text = str(clock)
    parts = text.split(":")

    if len(parts) != 2:
        return -1

    if not parts[0].isdigit():
        return -1

    if not parts[1].isdigit():
        return -1

    return (
        int(parts[0]) * 60
        + int(parts[1])
    )


def _qualifies(sport, comp):
    competitors = comp["competitors"]

    if len(competitors) < 2:
        return False

    status = comp["status"]
    status_type = status["type"]

    state = str(
        status_type.get("state", "")
    )

    if state != "in":
        return False

    away = competitors[0]
    home = competitors[1]

    away_score = int(
        away.get("score", "0")
    )

    home_score = int(
        home.get("score", "0")
    )

    margin = abs(
        away_score - home_score
    )

    period = int(
        status.get("period", 0)
    )

    clock = str(
        status.get("displayClock", "")
    )

    if sport == "MLB":
        return (
            period >= 8
            and margin <= 1
        )

    seconds = _clock_seconds(clock)

    if seconds < 0:
        return False

    if seconds > 300:
        return False

    if sport == "NFL":
        return (
            period == 4
            and margin <= 8
        )

    if sport == "NCAA FOOTBALL":
        return (
            period == 4
            and margin <= 8
        )

    if sport == "NCAA BASKETBALL":
        return (
            period == 2
            and margin <= 6
        )

    if sport == "NBA":
        return (
            period == 4
            and margin <= 6
        )

    if sport == "NHL":
        return (
            period == 3
            and margin <= 1
        )

    return False


def _find_alerts(ctx, sport):
    url = _endpoint(sport)

    if url == "":
        return []

    response = http.get(
        url,
        headers={},
        params={},
        ttl_seconds=60
    )

    if response["status_code"] != 200:
        return []

    data = response["json"]

    events = data.get(
        "events",
        []
    )

    alerts = []

    for event in events:
        competitions = event.get(
            "competitions",
            []
        )

        if len(competitions) == 0:
            continue

        comp = competitions[0]

        competitors = comp.get(
            "competitors",
            []
        )

        if len(competitors) < 2:
            continue

        away = competitors[0]
        home = competitors[1]

        away_team = away["team"]
        home_team = home["team"]

        if not _team_selected(
            ctx,
            sport,
            away_team
        ):
            if not _team_selected(
                ctx,
                sport,
                home_team
            ):
                continue

        if not _qualifies(
            sport,
            comp
        ):
            continue

        status = comp["status"]

        alerts.append(
            {
                "sport": sport,
            "away_id": str(
                away_team.get(
                    "id",
                    ""
                )
            ),
            "home_id": str(
                home_team.get(
                    "id",
                    ""
                )
            ),
            

                "away": str(
                    away_team.get(
                        "abbreviation",
                        "AWY"
                    )
                ),

                "home": str(
                    home_team.get(
                        "abbreviation",
                        "HOME"
                    )
                ),

                "away_name": str(
                    away_team.get(
                        "displayName",
                        ""
                    )
                ),

                "home_name": str(
                    home_team.get(
                        "displayName",
                        ""
                    )
                ),

                "away_score": int(
                    away.get(
                        "score",
                        "0"
                    )
                ),

                "home_score": int(
                    home.get(
                        "score",
                        "0"
                    )
                ),

                "clock": str(
                    status.get(
                        "displayClock",
                        ""
                    )
                ),

                "period": int(
                    status.get(
                        "period",
                        0
                    )
                ),

                "detail": str(
                    status["type"].get(
                        "detail",
                        ""
                    )
                )
            }
        )

    return alerts


def _logo_asset(sport, team_name, team_id):
    if sport == "NFL":
        logos = {
            "Arizona Cardinals": "ari.png",
            "Atlanta Falcons": "atl.png",
            "Baltimore Ravens": "bal.png",
            "Buffalo Bills": "buf.png",
            "Carolina Panthers": "car.png",
            "Chicago Bears": "chi.png",
            "Cincinnati Bengals": "cin.png",
            "Cleveland Browns": "cle.png",
            "Dallas Cowboys": "dal.png",
            "Denver Broncos": "den.png",
            "Detroit Lions": "det.png",
            "Green Bay Packers": "gb.png",
            "Houston Texans": "hou.png",
            "Indianapolis Colts": "ind.png",
            "Jacksonville Jaguars": "jax.png",
            "Kansas City Chiefs": "kc.png",
            "Las Vegas Raiders": "lv.png",
            "Los Angeles Chargers": "lac.png",
            "Los Angeles Rams": "lar.png",
            "Miami Dolphins": "mia.png",
            "Minnesota Vikings": "min.png",
            "New England Patriots": "ne.png",
            "New Orleans Saints": "no.png",
            "New York Giants": "nyg.png",
            "New York Jets": "nyj.png",
            "Philadelphia Eagles": "phi.png",
            "Pittsburgh Steelers": "pit.png",
            "San Francisco 49ers": "sf.png",
            "Seattle Seahawks": "sea.png",
            "Tampa Bay Buccaneers": "tb.png",
            "Tennessee Titans": "titans.png",
            "Washington Commanders": "was.png"
        }
        return logos.get(team_name, "")

    if sport == "NCAA FOOTBALL":
        return "cfb_" + str(team_id) + ".png"

    if sport == "NCAA BASKETBALL":
        return "cbb_" + str(team_id) + ".png"

    if sport == "NBA":
        nba_logos = {
            "Atlanta Hawks": "nba_atl.png",
            "Boston Celtics": "nba_bos.png",
            "Brooklyn Nets": "nba_bkn.png",
            "Charlotte Hornets": "nba_cha.png",
            "Chicago Bulls": "nba_chi.png",
            "Cleveland Cavaliers": "nba_cle.png",
            "Dallas Mavericks": "nba_dal.png",
            "Denver Nuggets": "nba_den.png",
            "Detroit Pistons": "nba_det.png",
            "Golden State Warriors": "nba_gsw.png",
            "Houston Rockets": "nba_hou.png",
            "Indiana Pacers": "nba_ind.png",
            "LA Clippers": "nba_lac.png",
            "Los Angeles Lakers": "nba_lal.png",
            "Memphis Grizzlies": "nba_mem.png",
            "Miami Heat": "nba_mia.png",
            "Milwaukee Bucks": "nba_mil.png",
            "Minnesota Timberwolves": "nba_min.png",
            "New Orleans Pelicans": "nba_nop.png",
            "New York Knicks": "nba_nyk.png",
            "Oklahoma City Thunder": "nba_okc.png",
            "Orlando Magic": "nba_orl.png",
            "Philadelphia 76ers": "nba_phi.png",
            "Phoenix Suns": "nba_phx.png",
            "Portland Trail Blazers": "nba_por.png",
            "Sacramento Kings": "nba_sac.png",
            "San Antonio Spurs": "nba_sas.png",
            "Toronto Raptors": "nba_tor.png",
            "Utah Jazz": "nba_uta.png",
            "Washington Wizards": "nba_was.png"
        }
        return nba_logos.get(team_name, "")

    if sport == "NHL":
        nhl_logos = {
            "Anaheim Ducks": "nhl_ana.png",
            "Boston Bruins": "nhl_bos.png",
            "Buffalo Sabres": "nhl_buf.png",
            "Calgary Flames": "nhl_cgy.png",
            "Carolina Hurricanes": "nhl_car.png",
            "Chicago Blackhawks": "nhl_chi.png",
            "Colorado Avalanche": "nhl_col.png",
            "Columbus Blue Jackets": "nhl_cbj.png",
            "Dallas Stars": "nhl_dal.png",
            "Detroit Red Wings": "nhl_det.png",
            "Edmonton Oilers": "nhl_edm.png",
            "Florida Panthers": "nhl_fla.png",
            "Los Angeles Kings": "nhl_lak.png",
            "Minnesota Wild": "nhl_min.png",
            "Montreal Canadiens": "nhl_mtl.png",
            "New Jersey Devils": "nhl_njd.png",
            "New York Islanders": "nhl_nyi.png",
            "New York Rangers": "nhl_nyr.png",
            "Ottawa Senators": "nhl_ott.png",
            "Philadelphia Flyers": "nhl_phi.png",
            "Pittsburgh Penguins": "nhl_pit.png",
            "San Jose Sharks": "nhl_sjs.png",
            "Seattle Kraken": "nhl_sea.png",
            "St. Louis Blues": "nhl_stl.png",
            "Tampa Bay Lightning": "nhl_tbl.png",
            "Toronto Maple Leafs": "nhl_tor.png",
            "Utah Mammoth": "nhl_uta.png",
            "Vancouver Canucks": "nhl_van.png",
            "Vegas Golden Knights": "nhl_vgk.png",
            "Winnipeg Jets": "nhl_wpg.png",
            "Washington Capitals": "nhl_wsh.png"
        }
        return nhl_logos.get(team_name, "")

    if sport == "MLB":
        mlb_logos = {
            "Arizona Diamondbacks": "mlb_ari.png",
            "Atlanta Braves": "mlb_atl.png",
            "Baltimore Orioles": "mlb_bal.png",
            "Boston Red Sox": "mlb_bos.png",
            "Chicago Cubs": "mlb_chc.png",
            "Chicago White Sox": "mlb_chw.png",
            "Cincinnati Reds": "mlb_cin.png",
            "Cleveland Guardians": "mlb_cle.png",
            "Colorado Rockies": "mlb_col.png",
            "Detroit Tigers": "mlb_det.png",
            "Houston Astros": "mlb_hou.png",
            "Kansas City Royals": "mlb_kc.png",
            "Los Angeles Angels": "mlb_laa.png",
            "Los Angeles Dodgers": "mlb_lad.png",
            "Miami Marlins": "mlb_mia.png",
            "Milwaukee Brewers": "mlb_mil.png",
            "Minnesota Twins": "mlb_min.png",
            "New York Mets": "mlb_nym.png",
            "New York Yankees": "mlb_nyy.png",
            "Oakland Athletics": "mlb_oak.png",
            "Philadelphia Phillies": "mlb_phi.png",
            "Pittsburgh Pirates": "mlb_pit.png",
            "San Diego Padres": "mlb_sd.png",
            "San Francisco Giants": "mlb_sf.png",
            "Seattle Mariners": "mlb_sea.png",
            "St. Louis Cardinals": "mlb_stl.png",
            "Tampa Bay Rays": "mlb_tb.png",
            "Texas Rangers": "mlb_tex.png",
            "Toronto Blue Jays": "mlb_tor.png",
            "Washington Nationals": "mlb_wsh.png"
        }
        return mlb_logos.get(team_name, "")

    return ""

def _period_label(alert):
    sport = alert["sport"]
    period = alert["period"]

    if sport == "NFL":
        return "Q" + str(period)

    if sport == "NCAA FOOTBALL":
        return "Q" + str(period)

    if sport == "NCAA BASKETBALL":
        return "2H"

    if sport == "NBA":
        return "Q" + str(period)

    if sport == "NHL":
        return "P" + str(period)

    return ""


def _mlb_label(alert):
    period = alert["period"]

    if period == 8:
        return "8TH INNING"

    if period == 9:
        return "9TH INNING"

    if period == 10:
        return "10TH INNING"

    if period == 11:
        return "11TH INNING"

    if period == 12:
        return "12TH INNING"

    if period == 13:
        return "13TH INNING"

    if period == 14:
        return "14TH INNING"

    if period == 15:
        return "15TH INNING"

    return str(period) + "TH INNING"


def _team_font(team):
    if len(str(team)) >= 4:
        return "4x5"
    return "5x7"

def _team_x(team):
    return 25




def _team_y(team):
    if len(str(team)) >= 4:
        return 10
    return 9


def _draw_alert(c, alert):
    c.clear()

    c.progress_bar(
        0,
        0,
        128,
        8,
        100,
        color="red"
    )

    c.text_center(
        "CLOSE GAME ALERT",
        0,
        font="5x7",
        color="white"
    )

    away_logo = _logo_asset(
        alert["sport"],
        alert["away_name"],
        alert["away_id"]
    )

    home_logo = _logo_asset(
        alert["sport"],
        alert["home_name"],
        alert["home_id"]
    )

    if away_logo != "":
        c.image(
            away_logo,
            2,
            8
        )

    if home_logo != "":
        c.image(
            home_logo,
            108,
            8
        )

    if alert["sport"] == "MLB":
        score_text = (
            alert["away"]
            + " "
            + str(alert["away_score"])
            + " - "
            + str(alert["home_score"])
            + " "
            + alert["home"]
        )

        c.text_center(
            score_text,
            font=_team_font(alert["away"]),
            color="white"
        )

    else:
        c.text(
            alert["away"],
            25,
            10,
            font=_team_font(alert["away"]),
            color="white"
        )

    away_score = str(alert["away_score"])
    home_score = str(alert["home_score"])

    away_w = c.text_width(away_score, font="6x8")
    dash_w = c.text_width("-", font="6x8")
    home_w = c.text_width(home_score, font="6x8")

    gap = 2
    total_w = away_w + gap + dash_w + gap + home_w
    score_x = (128 - total_w) // 2

    c.text(
        away_score,
        score_x,
    )
    c.text(
        "-",
        score_x + away_w + gap,
        color="white"
    )
    c.text(
        home_score,
        score_x + away_w + gap + dash_w + gap,
    )

    c.text(
alert["home"],
        88,
        _team_y(alert["home"]),
        font=_team_font(alert["home"]),
        color="white"
        )

    if alert["sport"] == "MLB":
        status_text = _mlb_label(
            alert
        )

    else:
        status_text = (
            alert["clock"]
            + " "
            + _period_label(alert)
        )

    c.text_center(
        status_text,
        21,
        color="green"
    )


def _draw_empty(c):
    c.clear()

    c.progress_bar(
        0,
        0,
        128,
        8,
        100,
        color="red"
    )

    c.text_center(
        "CLOSE GAME ALERT",
        0,
        font="5x7",
        color="white"
    )

    c.text_center(
        "ALL CLEAR",
        13,
          font="6x8",
        color="white"
    )


def main(c, ctx):
    mode = str(ctx.inputs["mode"]).strip().upper()

    if "TEST" in mode:
        tests = [
            {
                "sport": "NFL",
                "away_id": "134938",
                "home_id": "12",
                "away_name": "Tennessee Titans",
                "home_name": "Kansas City Chiefs",
                "away": "TEN",
                "home": "KC",
                "away_score": 24,
                "home_score": 21,
                "clock": "2:34",
                "period": 4
            },
            {
                "sport": "NCAA FOOTBALL",
                "away_id": "2633",
                "home_id": "8",
                "away_name": "Tennessee Volunteers",
                "home_name": "Arkansas Razorbacks",
                "away": "TENN",
                "home": "ARK",
                "away_score": 24,
                "home_score": 21,
                "clock": "2:34",
                "period": 4
            },
            {
                "sport": "NCAA BASKETBALL",
                "away_id": "84",
                "home_id": "96",
                "away_name": "Indiana Hoosiers",
                "home_name": "Kentucky Wildcats",
                "away": "IND",
                "home": "UK",
                "away_score": 68,
                "home_score": 64,
                "clock": "2:34",
                "period": 2
            },
            {
                "sport": "NBA",
                "away_id": "13",
                "home_id": "2",
                "away_name": "Los Angeles Lakers",
                "home_name": "Boston Celtics",
                "away": "LAL",
                "home": "BOS",
                "away_score": 102,
                "home_score": 99,
                "clock": "2:34",
                "period": 4
            },
            {
                "sport": "NHL",
                "away_id": "29",
                "home_id": "7",
                "away_name": "Columbus Blue Jackets",
                "home_name": "Buffalo Sabres",
                "away": "CBJ",
                "home": "BUF",
                "away_score": 3,
                "home_score": 2,
                "clock": "2:34",
                "period": 3
            },
            {
                "sport": "MLB",
                "away_id": "143",
                "home_id": "144",
                "away_name": "Philadelphia Phillies",
                "home_name": "Atlanta Braves",
                "away": "PHI",
                "home": "ATL",
                "away_score": 4,
                "home_score": 3,
                "clock": "8TH",
                "period": 8
            }
        ]

        index = int(ctx.now.unix // 60) % len(tests)
        _draw_alert(c, tests[index])
        return

    sports = _sports_from_input(ctx.inputs["sport"])
    if len(sports) == 0:
        _draw_empty(c)
        return

    alerts = []
    for sport in sports:
        sport_alerts = _find_alerts(
            ctx,
            sport
        )
        for alert in sport_alerts:
            alerts.append(alert)

    if len(alerts) == 0:
        _draw_empty(c)
        return

    index = (
        (ctx.now.unix // 60) % len(alerts)
    )

    _draw_alert(
        c,
        alerts[index]
    )
