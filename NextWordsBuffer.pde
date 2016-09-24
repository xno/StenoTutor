/*
 *   This file is part of StenoTutor.
 *
 *   StenoTutor is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   StenoTutor is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *   Copyright 2013 Emanuele Caruso. See LICENSE.txt for details.
 */

// Represents a multi-word buffer containing the next target line.
// It uses lot of fields from StenoTutor class
public class NextWordsBuffer {
  // A list of integers containing all the words in the line
  ArrayList<Integer> nextWords = new ArrayList<Integer>();
  // A list of integers containing all the words in the next line
  ArrayList<Integer> nextLineWords = new ArrayList<Integer>();

  // Other state variables
  int highlightedWordIndex;
  int bufferSize;

  // Default constructor
  NextWordsBuffer(int bufferSize) {
    this.bufferSize = bufferSize;
    fillNewLine(1);
  }

  // Go to last item in the list
  void goToListEnd() {
    highlightedWordIndex = nextWords.size() - 1;
  }

  // Get current word dictionary index
  int getCurrentWordIndex() {
    return nextWords.get(highlightedWordIndex);
  }

  // Get next word dictionary index
  int getNextWordIndex() {
    highlightedWordIndex++;
    if (highlightedWordIndex < nextWords.size()) {
      addWordsToNextLine();
      return nextWords.get(highlightedWordIndex);
    } else {
      fillNewLine(nextWords.get(highlightedWordIndex-1));
      return getCurrentWordIndex();
    }
  }

  // Tries to add a word to the next line
  void addWordsToNextLine() {
    if (isSingleWordBuffer) return;
    int lastWordIndex;
    if (nextLineWords.size() > 0) {
      lastWordIndex = nextLineWords.get(nextLineWords.size() - 1);
    } else {
      lastWordIndex = nextWords.get(nextWords.size() - 1);
    }
    float usedBufferSize = getLineWidth(nextLineWords);
    long[] penaltyLimits = calculatePenaltyLimits();
    float partialLineWidth = getLineWidth(nextWords, max(highlightedWordIndex - 1, 0));

    while (usedBufferSize < partialLineWidth) {
      int nextWordIndex = getNextWordFromPool(lastWordIndex, penaltyLimits);
      nextLineWords.add(nextWordIndex);
      lastWordIndex = nextWordIndex;

      textFont(font, mainTextFontSize);
      usedBufferSize += textWidth(dictionary.get(nextWordIndex).word.trim() + " ");
    }

    // Remove this word because it finishes too far
    if (nextLineWords.size() > 0) {
      nextLineWords.remove(nextLineWords.size()-1);
    }
  }

  // Get line width
  float getLineWidth(ArrayList<Integer> words) {
    float result = 0;
    for (Integer wordIndex : words) {
      result += textWidth(dictionary.get(wordIndex).word.trim() + " ");
    }
    return result;
  }

  // Get partial line width
  float getLineWidth(ArrayList<Integer> words, int maxWordIndex) {
    float result = 0;
    for (int i = 0; i < maxWordIndex; i++) {
      result += textWidth(dictionary.get(words.get(i)).word.trim() + " ");
    }
    return result;
  }

  // Fill a new line
  void fillNewLine(int previousWordIndex) {
    int lastWordIndex = previousWordIndex;

    // Clear word list
    nextWords.clear();

    // Store the used space
    float usedBufferSize = 0;

    // Calculate current min and max penalty limits
    long[] penaltyLimits = calculatePenaltyLimits();

    // If there are words in the next line, first use them
    for (Integer wordIndex : nextLineWords) {
      nextWords.add(wordIndex);

      textFont(font, mainTextFontSize);
      usedBufferSize += textWidth(dictionary.get(wordIndex).word.trim() + " ");
      lastWordIndex = wordIndex;
    }

    // Clear the next line, no longer needed
    nextLineWords.clear();

    // Fill the new line as long as there is space in the buffer
    while (usedBufferSize < bufferSize) {
      int nextWordIndex = getNextWordFromPool(lastWordIndex, penaltyLimits);
      nextWords.add(nextWordIndex);
      lastWordIndex = nextWordIndex;

      textFont(font, mainTextFontSize);
      usedBufferSize += textWidth(dictionary.get(nextWordIndex).word.trim() + " ");

      // If only one word is required, break the loop
      if (isSingleWordBuffer) break;
    }

    // Remove this word because it probably finishes off-screen,
    // unless it's the only one
    if (nextWords.size() > 1) nextWords.remove(nextWords.size()-1);

    // Highlight first word
    highlightedWordIndex = 0;
  }

  // Compute the next word. Slow-typed words have more possibilities
  // to show up than fast-typed ones
  int getNextWordFromPool(int previousWordIndex, long[] penaltyLimits) {
    // Create word pool
    ArrayList<Integer> wordPool = new ArrayList<Integer>();

    int dictionaryLast = dictionary.size();

    // For each unlocked word, if it's not the current one and it
    // isn't blacklisted, add it to the pool a number of times,
    // based on word penalty.
    for (int i = 0; i < startBaseWords + unlockedWords; i++) {
      if (i == previousWordIndex || i >= dictionaryLast || wordsBlacklist.contains(dictionary.get(i).word)) continue;
      else {
        int penalty = (int) map(wordStats.get(i).getWordPenalty(), penaltyLimits[0], penaltyLimits[1], 1, 100);
        for (int j = 0; j < penalty; j++) wordPool.add(i);
      }
    }

    // Fetch a random word from the word pool
    return wordPool.get((int) random(0, wordPool.size()));
  }

  // Calculate current min and max penalty limits
  long[] calculatePenaltyLimits() {
    long currentMinPenalty = 1000000000;
    long currentMaxPenalty = 0;
    for (int i = 0; i < min(dictionary.size(), startBaseWords + unlockedWords); i++) {
      if (i == currentWordIndex || wordsBlacklist.contains(dictionary.get(i).word)) continue;
      long penalty = wordStats.get(i).getWordPenalty();
      if (currentMinPenalty > penalty) currentMinPenalty = penalty;
      if (currentMaxPenalty < penalty) currentMaxPenalty = penalty;
    }
    return new long[] {currentMinPenalty, currentMaxPenalty};
  }

  // Draw target line text
  void showText(int x, int y) {
    float currentX = x;
    textFont(font, mainTextFontSize);
    for (int i = 0; i < nextWords.size(); i++) {
      int index = nextWords.get(i);
      String word = dictionary.get(index).word;
      if (i == highlightedWordIndex) {
        noFill();
        stroke(250, 200, 100);
        line(currentX, y + mainTextFontSize / 5, currentX + textWidth(word), y + mainTextFontSize / 5);
        fill(250, 200, 100);
      }
      text(word, currentX, y);
      if (i == highlightedWordIndex) fill(isLessonPaused ? 200 : 250);
      currentX += textWidth(word + " ");
    }

    // Draw next line
    currentX = x;
    for (int i = 0; i < nextLineWords.size(); i++) {
      if (nextLineWords.size() < 3) {
        fill(25);
      } else {
        fill(min(250, 25 * (nextLineWords.size() - i)));
      }
      int index = nextLineWords.get(i);
      String word = dictionary.get(index).word;
      text(word, currentX, y + mainTextFontSize);
      fill(isLessonPaused ? 200 : 250);
      currentX += textWidth(word + " ");
    }
  }
}