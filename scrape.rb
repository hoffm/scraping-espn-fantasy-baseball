# frozen_string_literal: true

require 'dotenv/load'
require 'httparty'
require 'nokogiri'
require 'pry'

REQ_HEADERS = {
  'accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
  'accept-language' => 'en-US,en;q=0.9',
  'cache-control' => 'no-cache',
  'pragma' => 'no-cache',
  'cookie' => "espn_s2=#{ENV['ESPN_S2_COOKIE']}"
}.freeze

URL = 'https://fantasy.espn.com/apis/v3/games/flb/seasons/2021/segments/0/leagues/16460?scoringPeriodId=11&view=modular&view=mNav&view=mMatchupScore&view=mScoreboard&view=mSettings&view=mTopPerformers&view=mTeam'

STAT_CODES = {
  20 => 'R',
  5 => 'HR',
  21 => 'RBI',
  23 => 'SB',
  2 => 'AVG',
  48 => 'K',
  63 => 'QS',
  57 => 'SV',
  47 => 'ERA',
  41 => 'WHIP'
}.freeze

response = HTTParty.get(URL, headers: REQ_HEADERS)

data = JSON.parse(response.body)

team_codes = data['teams'].each_with_object({}) do |team, accum|
  accum[team['id']] = team['abbrev'].strip
end

result = {}

data['schedule'].each do |match_up|
  next if match_up['winner'] === 'UNDECIDED' # BYE

  week = match_up['matchupPeriodId']
  next if week > 20

  ['home', 'away'].each do |venue|
    next unless match_up[venue]

    team_id = match_up[venue]['teamId']

    match_up_stats = match_up[venue]['cumulativeScore']['scoreByStat']

    stats_data = STAT_CODES.keys.each_with_object({}) do |stat_key, res|
      name = STAT_CODES[stat_key]
      score = match_up_stats[stat_key.to_s]['score']
      res[name] = score
    end

    team_name = team_codes[team_id]
    result[team_name] ||= {}
    result[team_name][week] = stats_data
  end
end

CSV.open('2021_murphy_stats.csv', 'wb') do |csv|
  csv << ['team', 'week', *STAT_CODES.values]

  result.each do |team_name, stats|
    stats.each do |week, scores|
      score_values = scores.values_at(*STAT_CODES.values)
      csv << [team_name, week, *score_values]
    end
  end
end
